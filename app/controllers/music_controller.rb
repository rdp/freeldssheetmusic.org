class MusicController < StoreController
 @@per_page = 11

 skip_before_filter :verify_authenticity_token, :only => [:add_comment, :search]

 def add_comment
  product = Product.find(params['id'])
   if (params['recaptcha'] || '').downcase != 'monday'
    flash[:notice] = 'Recaptcha failed -- hit back in your browser and try again'
   else
     new_hash = {}
     # extract the ones we care about
     for key in [:id, :comment, :user_name, :user_email, :user_url, :overall_rating, :difficulty_rating]
      new_hash[key] = params[key]
     end
     product.comments << Comment.new(new_hash)
     flash[:notice] = 'Comment saved'
   end
   redirect_to :action => :show, :id => product.code
 end

 def product_matches p, parent_tag_groups
  # it must match one member of each group
  for tag_ids in parent_tag_groups.values
    return false if (tag_ids - p.tag_ids).length == tag_ids.length # no intersection? you're done
  end
  true
 end

 def advanced_search_post
   tags = params[:product][:tag_ids].map{|id| Tag.find(id)}
  
   parent_tag_groups = {}
   for tag in tags
    if tag.parent
      parent_id = tag.parent.id
      child_id = tag.id
    else
      # allow for parent tags, too
      parent_id = child_id = tag.id
    end
     parent_tag_groups[parent_id] ||= []
     parent_tag_groups[parent_id] << child_id
   end

   all_products = Product.find(:all) # LODO sql for all this :)
  
   @products = all_products.select{|p|
     product_matches(p, parent_tag_groups)
   }
  
   @do_not_paginate = true # XXXX enable paginate
   render :action => 'index.rhtml'
 end

  # Shows products by tag or tags.
  # Tags are passed in as id #'s separated by commas.
  #
  def show_by_tags
    # Tags are passed in as an array.
    # Passed into this controller like this:
    # /store/show_by_tags/tag_one/tag_two/tag_three/...
    @tag_names = params[:tags] || []
    # Generate tag ID list from names
    tag_ids_array = Array.new
    for name in @tag_names
      temp_tag = Tag.find_by_name(name)
      if temp_tag then
        tag_ids_array << temp_tag.id
      else
        render(:file => "#{RAILS_ROOT}/public/404.html", :status => 404) and return
      end
    end

    if tag_ids_array.size == 0
      render(:file => "#{RAILS_ROOT}/public/404.html", :status => 404) and return
    end

    @viewing_tags = Tag.find(tag_ids_array, :order => "parent_id ASC")
    viewing_tag_names = @viewing_tags.collect { |t| " > #{t.name}"}
    @title = "Songs #{viewing_tag_names}"
    @tags = Tag.find_related_tags(tag_ids_array)

    # Paginate products so we don't have a ton of ugly SQL
    # and conditions in the controller
    list = Product.find_by_tags(tag_ids_array, true)
    pager = Paginator.new(list, list.size, @@per_page, params[:page])
    @products = returning WillPaginate::Collection.new(params[:page] || 1, @@per_page, list.size) do |p|
      p.replace list[pager.current.offset, pager.items_per_page]
    end

    render :action => 'index.rhtml'
  end
  
  
  # Downloads a file using the old system :P
  
  def download_file
    # find download...
    file = Download.find(:first, :conditions => ["id = ?", params[:download_id]])
    
    if file && File.exist?(file.full_filename)
      send_file(file.full_filename)
    else
      render(:file => "#{RAILS_ROOT}/public/404.html", :status => 404) and return
    end
  end

  # Our simple store index
  def index
    @title = "Songs"
    respond_to do |format|
      format.html do
        @tags = Tag.find_alpha
        @tag_names = nil
        @viewing_tags = nil
        @products = Product.paginate(
          :order => 'name ASC',
          :conditions => Product::CONDITIONS_AVAILABLE,
          :page => params[:page],
          :per_page => @@per_page
        )
        render :action => 'index.rhtml' and return
      end
      format.rss do
        @products = Product.find(
          :all,
          :conditions => Product::CONDITIONS_AVAILABLE,
          :order => "date_available DESC"
        )
        render :action => 'index.rxml', :layout => false and return
      end
    end
  end 
  
  def search
    @search_term = params[:search_term]
    @title = "Search Results for: #{@search_term}"
    
    # XXX paginate :)
    
    @products = Product.find(:all,
      :order => 'name ASC',
      :conditions => [
        "(name LIKE ? OR code = ?) AND #{Product::CONDITIONS_AVAILABLE}", 
        "%#{@search_term}%", @search_term
      ]
    )

    # search for tags, too
    @tags = Tag.find(:all,
      :order => 'name ASC',
      :conditions => [
        "(name LIKE ?)", 
        "%#{@search_term}%"
      ]
    )
    
    all_ids = @products.map(&:id) + @tags.map{|t| t.products.map(&:id)}.flatten
    # re map to fellas...
    @products = all_ids.uniq.map{|id| Product.find(id) }
    
    # If only one product comes back, take em directly to it.
    if @products.size == 1
      redirect_to :action => 'show', :id => @products[0].code and return
    else
      render :action => 'index.rhtml'
    end
  end

end
