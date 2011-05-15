require 'test/unit'
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'asset_id'
require 'rubygems'

class AssetTest < Test::Unit::TestCase
  
  def setup
    AssetID::Cache.empty
    @asset = AssetID::Asset.find(['favicon.ico']).first
    AssetID::Cache.empty
  end
  
  def test_find_assets_in_paths
    assets = AssetID::Asset.find(['favicon.ico', 'images', 'javascripts', 'stylesheets'])
    assert_equal 4, assets.count
  end
  
  def test_absolute_path
    assert_equal File.join(Rails.root, 'public', 'favicon.ico'), @asset.absolute_path
  end
  
  def test_relative_path
    assert_equal '/favicon.ico', @asset.relative_path
  end
  
  def test_fingerprint
    assert_equal '/favicon-id-b7d192a44e0da16cd180ebe85efb7c8f.ico', @asset.fingerprint
  end
  
  def test_is_file
    assert @asset.is_file?
  end
  
  def test_gzip
    asset = AssetID::Asset.find(['javascripts']).first
    raw = asset.data
    asset.gzip!
    assert asset.data != raw, 'Data is not Gzipped'
  end
  
  def test_parse_css
    asset = AssetID::Asset.find(['stylesheets']).first
    asset.replace_css_images!
    assert_equal 'body { background: url(/images/thundercats-id-982f2a3a4d905189959e848badb4f55b.jpg); }', asset.data
  end
  
  def test_parse_css_with_prefix
    asset = AssetID::Asset.find(['stylesheets']).first
    asset.replace_css_images!(:prefix => 'https://example.com')
    assert_equal 'body { background: url(https://example.com/images/thundercats-id-982f2a3a4d905189959e848badb4f55b.jpg); }', asset.data
  end
  
end

class Rails
  def self.root
    File.expand_path(File.join(File.dirname(__FILE__), 'sandbox'))
  end
end