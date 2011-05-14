require 'digest/md5'
require 'mime/types'
require 'aws/s3'
require 'time'
require 'yaml'

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
    
    def self.expiry_date
      @expiry_date ||= (Time.now + (60*60*24*365)).httpdate
    end
    
    def self.cache_headers
      {'Expires' => expiry_date, 'Cache-Control' => 'public'} # 1 year expiry
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
    
    def self.cache_path
      File.join(Rails.root, 'log', 'asset_id_cache.yml')
    end
    
    def self.upload(options={})
      options[:cache] ||= true
      connect_to_s3
      
      cache = {}
      if options[:cache]
        cache = YAML.load_file(cache_path) rescue {}
      end
      
      assets.each do |asset|
        fp = fingerprint(asset)
        
        puts "asset_id: Uploading #{asset} as #{fp}" if options[:debug] 
                
        mime_type = MIME::Types.of(asset).first.to_s
        
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
        
        puts "asset_id: headers: #{headers.inspect}" if options[:debug]
        
        if options[:cache] and cache[asset] and cache[asset][:fingerprint] == fp
          puts "asset_id: Cache hit #{asset} - doing nothing" 
        else
          AWS::S3::S3Object.store(
            fp,
            data,
            s3_bucket,
            headers
          ) unless options[:dry_run]
        end
        
        cache[asset] = {:expires => expiry_date.to_s, :fingerprint => fp}
      end
      
      puts "cache:\n#{YAML.dump(cache)}" if options[:debug]
      File.open(cache_path, 'w') {|f| f.write(YAML.dump(cache))} unless options[:dry_run]
    end
    
  end
end
