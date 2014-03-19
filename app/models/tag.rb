require_dependency RAILS_ROOT + "/vendor/plugins/substruct/app/models/tag"

class Tag
  validate :no_underscores
  def no_underscores
    if self.name =~ /_/
     errors.add(:name, "has _")
    end
  end

  def all_products_hits
    sum = 0
    self.products.each{|p| sum += p.view_count}
    sum
  end

  def all_products_redirects
    sum = 0
    self.products.each{|p| sum += p.redirect_count}
    sum
  end

  def remove_other_tag_from_all_my_children offending_tag
    self.products.each{|p| p.remove_tag_id offending_tag.id}
  end

  def all_products_pdf_downloads
    sum = 0
    self.products.each{|p| sum += p.pdf_download_count}
    sum
  end

  def super_children_tags
    if self.children.length > 0
      [self, self.children.map{|c| c.super_children_tags}].flatten
    else
     self
    end
  end

  def super_children_products_with_dups
    super_children_tags.map{|t| t.products}.flatten
  end

  # sync all hymns amongst themselves
  def self.sync_all_topics_with_all_hymns
    hymns_children = Tag.all.select{|t| t.is_hymn_tag?}
    hymns_parents = hymns_children.map{|t| t.parent}.uniq
    return '' if hymns_parents.size == 0 # for the other unit tests.and running  adev server..guess I could use fixtures after all :P
    errors = []
    for hymns_parent in hymns_parents
      hymns = hymns_parent.children
      unless hymns.length > 0
        raise
      end
      for hymn in hymns
        success = share_tags_among_hymns_products(hymn)
        errors << hymn.name unless success
      end
    end
    if errors.length > 0
      "Warning: no topics associated with any hymns for:" + errors.join(', ')
    else
      ''
    end
  end
  
  def self.share_tags_among_hymns_products hymn_tag
    all_topic_ids = {}
    topics = Tag.find_by_name("Topics")
    raise unless topics
    products = hymn_tag.products
    for product in products
      hymn_tags = product.hymn_tags
      if hymn_tags.length > 1 
        next
      end
      for tag in product.topic_tags
        all_topic_ids[tag.id] = true
      end
    end

    for product in products
      product.tag_ids = product.tag_ids | all_topic_ids.keys # union of the two arrays of ints
    end
    
    if all_topic_ids.length > 0
      true
    else
      false
    end
  end

  def is_hymn_tag? # accomodate primary, too
    self.parent && (self.parent.name =~ /^hymn/i || self.parent.name =~ /arrangements/i)
  end

  def valid_products
   self.products.select{|p| p.date_available < Time.now}
  end

  def is_composer_tag?
    self.parent && (self.parent.name =~ /^composer/i)
  end

  def is_topic_tag?
    self.parent && (self.parent.name =~ /^topic/i)
  end

  def is_original_tag?
    self.name =~ /^original/i
  end

  def get_composer_contact_url
     if composer_contact_url.present? 
       composer_contact_url
     elsif composer_email_if_contacted.present?
       "mailto:" + composer_email_if_contacted
     else
       nil # I'm not a composer tag...
     end
  end

  after_update {
    #Cache.clear! # no idea what damage this did...probs changed, normals changed...
  }

  after_destroy { 
    #Cache.clear! 
  } # some were marked with it, left side is messed up...may as well start over...

  after_save { |tag|
    # case of creating a "new" one I guess...
    #Cache.delete_by_type 'tags'# cached left side is messed now
    tag.clear_public_cached
    tag.parent.andand.clear_public_cached # in case it needs to add one to its children now...
    # NB this is still not enough, if a tag gains its first product it should reset more apparently...
    tag.products.each{|p| p.clear_my_cache} # hopefully no...infinite recursion here since the product just calls back to tags.clear_public_cached...
  } 

  def clear_public_cached
    files = Dir[RAILS_ROOT + '/public/cache/' + self.name.gsub('/', '_').gsub(' ', '_') + '*'] # SATB causes SATBB clear too but...
    files += Dir[RAILS_ROOT + '/public/cache/all_songs*'] # this one too :)
    Rails.logger.info "clearing #{files.inspect}"
    files.each{|f| File.delete f}
    files
  end

  # Finds ordered parent tags by rank.
  def self.find_ordered_parents
    find(
      :all,
      :conditions => "parent_id IS NULL OR parent_id = 0",
#      :include => [:parent, :children], # we don't want *all* children though...that seems kind of wasteful, esp. since we cache output anyway now
      :order => "-rank DESC"
    )
  end

  def abbreviated_name
             name_to_use = self.name.gsub(',', '') # Hope this never does anything...
             words = name_to_use.split(/[ \/]/)
             # don't say "a" for a capella
             # also don't do word ... when you could fit "word word2" :)
             # also don't do 2... for "2 part choir"
             # also don't do friend... for friend/friendship [too long]
             # 2 part choir -> 2 part choir, not 2 part ...
             # comfort/strength/courage -> comfort/strength...
             if (words.size > 1 && words.size != 3) || name_to_use.length > 20
               splitter_loc = (name_to_use =~ /[ \/]/)
               first_two_words = words[0..1]
               # don't write organ/organ
               if first_two_words[0] == first_two_words[1]
                 first_two_words.pop # off the last one
               end
               split_by_slashes = name_to_use.split('/')
               if split_by_slashes.size > 1 && split_by_slashes[0].split[0] == split_by_slashes[1].split[0]
                 # don't write harp solo for harp solo/optional harp accompaniment
                 first_two_words = [split_by_slashes[0].split[0]] # harp solo/harp accompaniment -> "harp" since otherwise it looks like it's a solo...
               end
               first_part_of_name = first_two_words.join(name_to_use[splitter_loc..splitter_loc]) # preserve that slash :)
               name_to_use = first_part_of_name + "&hellip;"
             else
               name_to_use = name_to_use # whole name, sans commas :)
             end
             name_to_use
  end


end
