#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:npm) do
  before :each do
    @resource =  Puppet::Type.type(:package).new(
      :name   => 'express',
      :ensure => :present
    )
    @provider = described_class.new(@resource)
    @provider.class.stubs(:optional_commands).with(:npm).returns '/usr/local/bin/npm'
    @provider.class.stubs(:command).with(:npm).returns '/usr/local/bin/npm'
  end

  def self.it_should_respond_to(*actions)
    actions.each do |action|
      it "should respond to :#{action}" do
        expect(@provider).to respond_to(action)
      end
    end
  end

  it_should_respond_to :install, :uninstall, :update, :query, :latest

  describe 'when installing npm packages' do
    it 'should use package name by default' do
      @provider.expects(:npm).with('install', '--global', 'express')
      @provider.install
    end

    describe 'and a source is specified' do
      it 'should use the source instead of the gem name' do
        @resource[:source] = '/tmp/express.tar.gz'
        @provider.expects(:npm).with('install', '--global', '/tmp/express.tar.gz')
        @provider.install
      end
    end
  end

  describe 'when npm packages are installed globally' do
    before :each do
      @provider.class.instance_variable_set(:@npmlist, nil)
    end

    it 'should return a list of npm packages installed globally' do
      @provider.class.expects(:execute).with(['/usr/local/bin/npm', 'list', '--json', '--global'], anything).returns(my_fixture_read('npm_global'))
      expect(@provider.class.instances.map(&:properties).sort_by { |res| res[:name] }).to eq([
        { :ensure => '2.5.9', :provider => 'npm', :name => 'express' },
        { :ensure => '1.1.15', :provider => 'npm', :name => 'npm' },
      ])
    end

    it 'should log and continue if the list command has a non-zero exit code' do
      @provider.class.expects(:execute).with(['/usr/local/bin/npm', 'list', '--json', '--global'], anything).returns(my_fixture_read('npm_global'))
      Process::Status.any_instance.expects(:success?).returns(false)
      Process::Status.any_instance.expects(:exitstatus).returns(123)
      Puppet.expects(:debug).with(regexp_matches(/123/))
      expect(@provider.class.instances.map(&:properties)).not_to eq([])
    end

    it "should log and return no packages if JSON isn't output" do
      @provider.class.expects(:execute).with(['/usr/local/bin/npm', 'list', '--json', '--global'], anything).returns('failure!')
      Process::Status.any_instance.expects(:success?).returns(true)
      Puppet.expects(:debug).with(regexp_matches(/npm list.*failure!/))
      expect(@provider.class.instances).to eq([])
    end
  end

  describe "#latest" do
    it "filters npm registry logging" do
      provider.expects(:npm).with('view', 'express', 'version').returns("npm http GET https://registry.npmjs.org/express\nnpm http 200 https://registry.npmjs.org/express\n2.0.0")
      expect(provider.latest).to eq('2.0.0')
    end
  end
end
