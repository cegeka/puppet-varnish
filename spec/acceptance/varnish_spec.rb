require 'spec_helper_acceptance'

describe 'varnish' do

  describe 'running puppet code' do
    it 'should work with no errors' do
      pp = <<-EOS
        include varnish
        include stdlib
        include stdlib::stages
        include profile::package_management
        
        class { 'cegekarepos' : stage => 'setup_repo' }

        Yum::Repo <| title == 'varnish-3_0' |>

        varnish::instance { 'site.example.com':
          address     => ['0.0.0.0:80'],
          admin_port  => '6083',
          options     => [
            'host = "127.0.0.1"',
            'port = "8080"',
            'connect_timeout = 600s',
            'first_byte_timeout = 600s',
            'between_bytes_timeout = 600s'
          ],
          storage     => ['file,/var/lib/varnish/varnish_storage.bin,1G'],
          release     => '3',
        }
        
        varnish::vcl { 'allow-backend':
          type     => 'recv',
          rules    => [
            'if (req.url ~ "^/api/") {
              return (pass);
            }'
          ],
          instance => 'site.example.com',
        }
 
      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, :catch_failures => true)
      apply_manifest(pp, :catch_changes => true)
    end

    describe port(80) do
      it { is_expected.to be_listening }
    end
    
    describe port(6083) do
      it { is_expected.to be_listening }
    end

    describe service('varnish-site.example.com') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe file('/etc/varnish/site.example.com/production-3.vcl') do
      it { should be_file }
    end

    describe file('/etc/varnish/site.example.com/recv.vcl') do
      it { should be_file }
      it { should contain '(req.url ~ "^/api/")' }
    end

  end
end
