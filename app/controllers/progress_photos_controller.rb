# frozen_string_literal: true

# Manages progress photos for physique tracking
# Supports photo upload with camera capture, date overlay, and category organization
class ProgressPhotosController < ApplicationController
  before_action :set_progress_photo, only: %i[show destroy]

  # GET /progress_photos
  # Gallery view with category filters and timeline
  def index
    @progress_photos = Current.user.progress_photos.ordered

    # Filter by category if specified
    if params[:category].present? && ProgressPhoto::CATEGORIES.include?(params[:category])
      @progress_photos = @progress_photos.by_category(params[:category])
      @active_category = params[:category]
    end

    # Group photos by month for timeline view
    @photos_by_month = @progress_photos.group_by { |p| p.taken_at.strftime('%B %Y') }
  end

  # GET /progress_photos/new
  # Photo upload form with camera capture support
  def new
    @progress_photo = Current.user.progress_photos.build(
      taken_at: Time.current,
      category: params[:category] || 'front'
    )
  end

  # GET /progress_photos/:id
  # Full-screen photo view with date overlay
  def show
  end

  # POST /progress_photos
  def create
    @progress_photo = Current.user.progress_photos.build(progress_photo_params)

    if @progress_photo.save
      redirect_to progress_photos_path, notice: 'Progress photo saved.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /progress_photos/:id
  def destroy
    @progress_photo.destroy
    redirect_to progress_photos_path, notice: 'Progress photo deleted.'
  end

  # GET /progress_photos/compare
  # Side-by-side photo comparison
  def compare
    @photos = Current.user.progress_photos.ordered

    if params[:category].present?
      @photos = @photos.by_category(params[:category])
    end

    @left_photo = Current.user.progress_photos.find_by(id: params[:left]) if params[:left].present?
    @right_photo = Current.user.progress_photos.find_by(id: params[:right]) if params[:right].present?
  end

  private

  def set_progress_photo
    @progress_photo = Current.user.progress_photos.find(params[:id])
  end

  def progress_photo_params
    params.require(:progress_photo).permit(:taken_at, :category, :notes, :photo)
  end
end
