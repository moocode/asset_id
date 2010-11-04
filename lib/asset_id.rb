require 'digest/md5'
require 'mime/types'
require 'aws/s3'

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
    
    def self.assets
      a = []
      asset_paths.each do |asset_path|
        path = File.join path_prefix, asset_path
        next unless File.exists? path
        if File.directory? path
          a += gather_assets_for(path)
        else
          a << path
        end
      end
      a
    end
    
    def self.gather_assets_for(dir)
      a = []
      Dir.glob(File.join dir, '/*').each do |file|
        if File.directory? file
          a += gather_assets_for(file)
        else
          a << file
        end
      end
      a
    end
    
    def self.fingerprint(path)
      path = File.join path_prefix, path unless path =~ /#{path_prefix}/
      #d = File.mtime(path).to_i.to_s
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
      {'Expires' => 1.year.from_now.httpdate, 'Cache-Control' => 'public'}
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
        puts "Uploading #{asset} as #{fingerprint(asset)}"
        mime_type = MIME::Types.of(asset).first
        
        headers = {
          :content_type => mime_type,
          :access => s3_permissions,
        }.merge(cache_headers)
        
        if gzip_types.include? mime_type
          data = `gzip -c #{asset}`
          headers.merge!(gzip_headers)
        else
          data = File.read(asset)
        end
        
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
