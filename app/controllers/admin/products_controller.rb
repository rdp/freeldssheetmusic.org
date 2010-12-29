require_dependency RAILS_ROOT + "/vendor/plugins/substruct/app/controllers/admin/products_controller"

class Admin::ProductsController < Admin::BaseController
  # Saves product from new and edit.
  #
  #
  def save
    # If we have ID param this isn't a new product
    if params[:id]
      @new_product = false
      @title = "Editing Product"
      @product = Product.find(params[:id])
    else
      @new_product = true
      @title = "New Product"
      @product = Product.new()
    end
    @product.attributes = params[:product]
		if @product.save
			# Save product tags
			# Our method doesn't save tags properly if the product doesn't already exist.
			# Make sure it gets called after the product has an ID
			@product.tag_ids = params[:product][:tag_ids] if params[:product][:tag_ids]
      # Build product images from upload
      image_errors = []
      unless params[:image].blank?
  			params[:image].each do |i|
          if i[:image_data] && !i[:image_data].blank?
            new_image = Image.new
            p i
            logger.info i.inspect
            logger.info i[:image_data].inspect
            # image_data is a file, really...
            new_image.uploaded_data = i[:image_data]
            if new_image.save
              @product.images << new_image
            else
              image_errors.push(new_image.filename + " " +  new_image.errors.map{|e| e.to_s}.join(' '))
            end
          end
        end
      end

      # it must just inspect the file?
      # Build downloads from form
      download_errors = []
      unless params[:download].blank?
  			params[:download].each do |i|
          if i[:download_data] && !i[:download_data].blank?
            new_download = Download.new
            logger.info i[:download_data].inspect
          
            new_download.uploaded_data = i[:download_data]
            if i[:download_data].original_filename =~ /\.pdf$/
             # also add them in as fake images
            begin
             0.upto(100) do |n|
               new_image = Image.new
               raise unless system("convert -density 125 #{i[:download_data].path}[#{n}] /tmp/yo.gif") # will fail eventually...
               fake_upload = Pathname.new('/tmp/yo.gif')
               def fake_upload.content_type
                'image/gif'
               end
               def fake_upload.original_filename
                'yo.gif'
               end
               new_image.uploaded_data = fake_upload
               if new_image.save
                @product.images << new_image
              else
                raise 'bad'
                end
             end
            rescue => e
              logger.info e.to_s
            end
             
            end
            if new_download.save
              @product.downloads << new_download
            else
              download_errors.push(new_download.filename)
            end
          end
        end
      end

      # Build variations from form
      if !params[:variation].blank?
        params[:variation].each do |v|
          variation = @product.variations.find_or_create_by_id(v[:id])
          variation.attributes = v
          variation.save
          @product.variations << variation
        end
      end
      
      flash[:notice] = "Product '#{@product.name}' saved."
      if image_errors.length > 0
        require '_dbg.rb'
        flash[:notice] += "<b>Warning:</b> Failed to upload image(s) #{image_errors.join(',')}. This may happen if the size is greater than the maximum allowed of #{Image::MAX_SIZE / 1024 / 1024} MB!"
      end
      if download_errors.length > 0
        flash[:notice] += "<b>Warning:</b> Failed to upload file(s) #{download_errors.join(',')}."
      end
      redirect_to :action => 'edit', :id => @product.id
    else
			@image = Image.new
			if @new_product
        render :action => 'new' and return
      else
        render :action => 'edit' and return
      end
    end    
  end

end