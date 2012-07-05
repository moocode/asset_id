require 'aws/s3'

module AssetID
  class S3
  
    def self.s3_config
      @@config ||= YAML.load_file(File.join(Rails.root, "config/asset_id.yml"))[Rails.env] rescue nil || {}
    end
  
    def self.connect_to_s3
      AWS::S3::Base.establish_connection!(
        :access_key_id => s3_config['access_key_id'],
        :secret_access_key => s3_config['secret_access_key']
      )
    end
  
    def self.s3_permissions
      :public_read
    end
  
    def self.s3_bucket
      s3_config['bucket']
    end
    
    def self.s3_folder
      s3_config['folder']
    end
    
    def self.s3_prefix
      s3_config['prefix'] || s3_bucket_url
    end
    
    def self.s3_bucket_url
      "http://#{s3_bucket}.s3.amazonaws.com#{s3_folder ? "/#{s3_folder}" : '' }"
    end
    
    def self.full_path(asset)
      s3_folder ? "/#{s3_folder}#{asset.fingerprint}" : asset.fingerprint
    end
    
    def self.upload(options={})
      Asset.init(:debug => options[:debug], :nofingerprint => options[:nofingerprint])
      
      assets = Asset.find
      return if assets.empty?
    
      connect_to_s3
    
      assets.each do |asset|
      
        puts "AssetID: #{asset.relative_path}" if options[:debug]
      
        headers = {
          :content_type => asset.mime_type,
          :access => s3_permissions,
        }.merge(asset.cache_headers)
        
        #load css md5 before replace_css_images
        asset.md5

        asset.replace_css_images!(:prefix => s3_prefix) if asset.css?
        
        if asset.gzip_type?
          headers.merge!(asset.gzip_headers)
          asset.gzip!
        end
        
        if options[:debug]
          puts "  - Uploading: #{full_path(asset)} [#{asset.data.size} bytes]"
          puts "  - Headers: #{headers.inspect}"
        end
        
        unless options[:dry_run]
          res = AWS::S3::S3Object.store(
            full_path(asset),
            asset.data,
            s3_bucket,
            headers
          ) 
          puts "  - Response: #{res.inspect}" if options[:debug]
        end
      end
    
      Cache.save! unless options[:dry_run]
    end
  
  end
end
