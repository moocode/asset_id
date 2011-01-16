require 'digest/md5'
require 'mime/types'
require 'aws/s3'
require 'time'
require 'zlib'

module AssetID
  
  class Base
    DEFAULT_ASSET_PATHS = ['favicon.ico', 'images', 'javascripts', 'stylesheets']
    @@asset_paths = DEFAULT_ASSET_PATHS
    
    def self.path_prefix
      File.join Rails.root, 'public'
    end
    
    def self.asset_paths=(paths)
      @@asset_paths = paths
    end
    
    def self.asset_paths
      @@asset_paths
    end
    
    def self.absolute_path(path)
      File.join path_prefix, path
    end
    
    def self.assets
      asset_paths.inject([]) {|assets, path|
        path = absolute_path(path)
        assets << path if File.exists? path and !File.directory? path
        assets += Dir.glob(path+'/**/*').inject([]) {|m, file| 
          m << file unless File.directory? file; m 
        }
      }
    end
    
    def self.fingerprint(path)
      path = File.join path_prefix, path unless path =~ /#{path_prefix}/
      d = Digest::MD5.hexdigest(File.read(path))
      path = path.gsub(path_prefix, '')
      File.join File.dirname(path), "#{File.basename(path, File.extname(path))}-id-#{d}#{File.extname(path)}"
    end
    
  end
  
  class S3 < AssetID::Base
    
    DEFAULT_GZIP_TYPES = ['text/css', 'application/javascript']
    @@gzip_types = DEFAULT_GZIP_TYPES
    
    def self.gzip_types=(types)
      @@gzip_types = types
    end
    
    def self.gzip_types
      @@gzip_types
    end
    
    def self.s3_config
      @@config ||= YAML.load_file(File.join(Rails.root, "config/asset_id.yml"))[Rails.env] rescue nil || {}
    end
    
    def self.connect_to_s3
      AWS::S3::Base.establish_connection!(
        :access_key_id => s3_config['access_key_id'],
        :secret_access_key => s3_config['secret_access_key']
      )
    end
    
    def self.cache_headers
      {'Expires' => (Time.now + (60*60*24*365)).httpdate, 'Cache-Control' => 'public'} # 1 year expiry
    end
    
    def self.gzip_headers
      {'Content-Encoding' => 'gzip', 'Vary' => 'Accept-Encoding'}
    end
    
    def self.s3_permissions
      :public_read
    end
    
    def self.s3_bucket
      s3_config['bucket']
    end
    
    def self.fingerprint(path)
      #File.join "/#{self.s3_bucket}", fingerprint(path)
      super(path)
    end
    
    def self.upload(options={})
      connect_to_s3
      assets.each do |asset|
        puts "asset_id: Uploading #{asset} as #{fingerprint(asset)}" if options[:debug]
        mime_type = MIME::Types.of(asset).first.to_s
        
        headers = {
          :content_type => mime_type,
          :access => s3_permissions,
        }.merge(cache_headers)

        data = File.read(asset)

        if mime_type == 'text/css'
          data.gsub! /url\((?:"([^"]*)"|'([^']*)'|([^)]*))\)/mi  do |match|
            begin
              # $1 is the double quoted string, $2 is single quoted, $3 is no quotes
              uri = ($1 || $2 || $3).to_s.strip

              puts "asset_id: Changing CSS URI #{uri} to #{fingerprint(uri)}" if options[:debug]

              # if the uri appears to begin with a protocol then the asset isn't on the local filesystem
              if uri =~ /[a-z]+:\/\//i
                "url(#{uri})"
              else
                "url(#{fingerprint(uri)})"
              end
            rescue Errno::ENOENT
              "url(#{uri})"
            end
          end
        end
        
        if gzip_types.include? mime_type
          headers.merge!(gzip_headers)
          
          data = returning StringIO.open('', 'w') do |gz_data|
            gz = Zlib::GzipWriter.new(gz_data, nil, nil)
            gz.write(data)
            gz.close
          end.string
        end
        
        puts "asset_id: headers: #{headers.inspect}" if options[:debug]
        
        AWS::S3::S3Object.store(
          fingerprint(asset),
          data,
          s3_bucket,
          headers
        ) unless options[:dry_run]
      end
    end
    
  end
end
