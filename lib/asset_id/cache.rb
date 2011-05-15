require 'yaml'

module AssetID
  class Cache
    
    def self.empty
      @cache = {}
    end
    
    def self.cache
      @cache ||= YAML.load_file(cache_path) rescue {}
    end
    
    def self.cache_path
      File.join(Rails.root, 'log', 'asset_id_cache.yml')
    end
    
    def self.get(asset)
      cache[asset.relative_path]
    end
    
    def self.hit?(asset)
      return true if cache[asset.relative_path] and cache[asset.relative_path][:fingerprint] == asset.fingerprint
      cache[asset.relative_path] = {:expires => asset.expiry_date.to_s, :fingerprint => asset.fingerprint}
      false
    end
  
    def self.miss?(asset)
      !hit?(asset)
    end
    
    def self.save!
      File.open(cache_path, 'w') {|f| f.write(YAML.dump(cache))}
    end
  
  end
end