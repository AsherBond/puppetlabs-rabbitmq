# frozen_string_literal: true

require 'spec_helper'

describe 'Puppet::Type.type(:rabbitmq_user_permissions).provider(:rabbitmqctl)' do
  let(:resource) do
    Puppet::Type::Rabbitmq_user_permissions.new(
      name: 'foo@bar'
    )
  end
  let(:provider_class) { Puppet::Type.type(:rabbitmq_user_permissions).provider(:rabbitmqctl) }
  let(:provider) { provider_class.new(resource) }

  after do
    provider_class.instance_variable_set(:@users, nil)
  end

  it 'matches user permissions from list' do
    provider.class.expects(:rabbitmqctl_list).with('user_permissions', 'foo').returns <<~EOT
      bar 1 2 3
    EOT
    expect(provider.exists?).to eq(configure: '1', write: '2', read: '3')
  end

  it 'matches user permissions with empty columns' do
    provider.class.expects(:rabbitmqctl_list).with('user_permissions', 'foo').returns <<~EOT
      bar			3
    EOT
    expect(provider.exists?).to eq(configure: '', write: '', read: '3')
  end

  it 'does not match user permissions with more than 3 columns' do
    provider.class.expects(:rabbitmqctl_list).with('user_permissions', 'foo').returns <<~EOT
      bar 1 2 3 4
    EOT
    expect { provider.exists? }.to raise_error(Puppet::Error, %r{cannot parse line from list_user_permissions})
  end

  it 'does not match an empty list' do
    provider.class.expects(:rabbitmqctl_list).with('user_permissions', 'foo').returns ''
    expect(provider.exists?).to eq(nil)
  end

  it 'creates default permissions' do
    provider.instance_variable_set(:@should_vhost, 'bar')
    provider.instance_variable_set(:@should_user, 'foo')
    provider.expects(:rabbitmqctl).with('set_permissions', '-p', 'bar', 'foo', "''", "''", "''")
    provider.create
  end

  it 'destroys permissions' do
    provider.instance_variable_set(:@should_vhost, 'bar')
    provider.instance_variable_set(:@should_user, 'foo')
    provider.expects(:rabbitmqctl).with('clear_permissions', '-p', 'bar', 'foo')
    provider.destroy
  end

  { configure_permission: '1', write_permission: '2', read_permission: '3' }.each do |k, v|
    it "is able to retrieve #{k}" do
      provider.class.expects(:rabbitmqctl_list).with('user_permissions', 'foo').returns <<~EOT
        bar 1 2 3
      EOT
      expect(provider.send(k)).to eq(v)
    end

    it "is able to retrieve #{k} after exists has been called" do
      provider.class.expects(:rabbitmqctl_list).with('user_permissions', 'foo').returns <<~EOT
        bar 1 2 3
      EOT
      provider.exists?
      expect(provider.send(k)).to eq(v)
    end
  end
  { configure_permission: %w[foo 2 3],
    read_permission: %w[1 2 foo],
    write_permission: %w[1 foo 3] }.each do |perm, columns|
    it "is able to sync #{perm}" do
      provider.class.expects(:rabbitmqctl_list).with('user_permissions', 'foo').returns <<~EOT
        bar 1 2 3
      EOT
      provider.resource[perm] = 'foo'
      provider.expects(:rabbitmqctl).with('set_permissions', '-p', 'bar', 'foo', *columns)
      provider.send("#{perm}=".to_sym, 'foo')
    end
  end
  it 'onlies call set_permissions once' do
    provider.class.expects(:rabbitmqctl_list).with('user_permissions', 'foo').returns <<~EOT
      bar 1 2 3
    EOT
    provider.resource[:configure_permission] = 'foo'
    provider.resource[:read_permission] = 'foo'
    provider.expects(:rabbitmqctl).with('set_permissions', '-p', 'bar', 'foo', 'foo', '2', 'foo').once
    provider.configure_permission = 'foo'
    provider.read_permission = 'foo'
  end
end
