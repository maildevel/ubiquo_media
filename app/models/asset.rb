# An asset is a resource with name, description and one associated
# file.
class Asset < ActiveRecord::Base
  belongs_to :asset_type

  has_many :asset_relations, :dependent => :destroy
  
  validates_presence_of :name, :asset_type_id, :type
  before_validation_on_create :set_asset_type
  after_update :uhook_after_update

  # Generic find (ID, key or record)
  def self.gfind(something, options={})
    case something
    when Fixnum
      find_by_id(something, options)
    when String, Symbol
      find_by_name(something.to_s, options)
    when Asset
      something
    else
      nil
    end
  end

  # filters:

  #   :type: ID of AssetType separated by commas
  #   :text: String to search in asset name and description
  #
  # options: find_options
  def self.filtered_search(filters = {}, options = {})
    filter_type = if filters[:type]
      types_id = filters[:type].to_s.split(",").map(&:to_i)
      {:find => {:conditions => ["assets.asset_type_id IN (?)", types_id]}}
    else {}
    end
    filter_text = unless filters[:text].blank?
      args = ["%#{filters[:text]}%"] * 2
      condition = "upper(assets.name) LIKE upper(?) OR upper(assets.description) LIKE upper(?)"
      {:find => {:conditions => [condition] + args}}
    else {}
    end
    filter_visibility = unless filters[:visibility].blank?
      {:find => {:conditions => ["assets.type = ?", "asset_#{filters[:visibility]}".classify]}}
    else {}
    end
    filter_create_start = if filters[:created_start]
      {:find => {:conditions => ["assets.created_at >= ?", filters[:created_start]]}}
    else {}
    end      
    filter_create_end = if filters[:created_end]
      {:find => {:conditions => ["assets.created_at <= ?", filters[:created_end]]}}
    else {}
    end   
    
    uhook_filtered_search(filters) do
      with_scope(filter_text) do
        with_scope(filter_type) do
          with_scope(filter_visibility) do
            with_scope(filter_create_start) do
              with_scope(filter_create_end) do  
                with_scope(:find => options) do
                  Asset.find(:all)
                end
              end
            end
          end
        end
      end
    end
  end
  
  def self.visibilize(visibility)
    "asset_#{visibility}".classify.constantize
  end
  
  private

  def set_asset_type
    if self.resource.errors.blank?
      # mime_types hash is here momentarily but maybe its must be in ubiquo config
      mime_types = Ubiquo::Config.context(:ubiquo_media).get(:mime_types)
      content_type = self.resource_content_type.split('/')
      mime_types.each do |type_relations|
        type_relations.last.each do |mime|
          if content_type.include?(mime)
            self.asset_type = AssetType.find_by_key(type_relations.first.to_s)
          end
        end
      end
      self.asset_type = AssetType.find_by_key("other") unless self.asset_type
    end
  end
end
