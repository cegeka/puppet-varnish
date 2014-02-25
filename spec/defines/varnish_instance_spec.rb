require 'spec_helper'

describe 'varnish::instance' do
  let (:params) {{ 
    :admin_port => '6083',
  }}
end
