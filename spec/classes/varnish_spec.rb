#!/usr/bin/env rspec

require 'spec_helper'

describe 'varnish' do
  it { should contain_class 'varnish' }
end
