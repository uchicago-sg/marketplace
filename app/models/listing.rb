class Listing < ActiveRecord::Base
  MAX_IMAGES = 5 # Maximum number of uploadable images

  # Available options for sorting
  ORDER_BY      = [['Most Recent', 'renewed_at DESC'], ['Lowest Price', 'listings.price ASC, renewed_at DESC'], ['Highest Price', 'listings.price DESC, renewed_at DESC']]
  ORDER_OPTIONS = []
  ORDER_BY.each_with_index do |e, i|
    ORDER_OPTIONS << [e[0], i]
  end
  DEFAULT_ORDER = ORDER_BY[0][1] # Most recent

  # Available modes for sorting
  MODES = %w( Detailed Compact )
  MODE_OPTIONS = []
  MODES.each_with_index do |e, i|
    MODE_OPTIONS << [e, i]
  end

  attr_accessible :description, :details, :price, :status, :images_attributes, :category_ids
  belongs_to :seller, :class_name => 'User' 
  has_and_belongs_to_many :categories
  has_many :images, :dependent => :destroy
  accepts_nested_attributes_for :images, :allow_destroy => :true
  has_paper_trail
  acts_as_taggable
  is_impressionable
  
  attr_readonly :permalink
  @@permalink_field = :description
  
  validates_uniqueness_of :description, :scope => :seller_id
  validates :description, :presence => true
  validates :details, :presence => true
  validates :price,
    :numericality => {
      :greater_than_or_equal_to => 0,
      :message => 'must be a number >= 0'
    }

  scope :with_images, joins(:images)
  scope :signed, joins(:seller).where('users.signed = ?', true)
  scope :published,   where(:published => true)
  scope :unpublished, where(:published => false)

  def unpublished?
    not published?
  end

  # Listing lifecycle
  # Please note the operations have day-granularity
  # Listings are...
  # - "available" for the first week
  # - "renewable" for the second week (plus the last day of their "availability")
  # - "expired" afterwards
  scope :available,   where('listings.renewed_at >= ?',  1.week.ago.beginning_of_day).where(:published => true)
  scope :unexpired,   where('listings.renewed_at >= ?', 2.weeks.ago.beginning_of_day)
  scope :expired,     where('listings.renewed_at  < ?', 2.weeks.ago.beginning_of_day)

  scope :renewable, where(
    'listings.renewed_at >= ? AND listings.renewed_at <= ?',
    2.weeks.ago.beginning_of_day, 6.days.ago.end_of_day
  ).where(:published => true)

  scope :almost_renewable, where(
    'listings.renewed_at >= ? AND listings.renewed_at <= ?',
    6.days.ago.beginning_of_day, 6.days.ago.end_of_day
  ).where(:published => true)

  def self.readable
    self.unexpired.published
  end

  def available?
    return true if published? and renewed_at >= 1.week.ago.beginning_of_day
    false
  end

  def expired?
    renewed_at < 2.weeks.ago.beginning_of_day
  end

  def unexpired?
    not expired?
  end

  def renewable?
    return true if published? and renewed_at >= 2.weeks.ago.beginning_of_day and renewed_at <= 6.days.ago.end_of_day
    false
  end

  def almost_renewable?
    return true if published? and renewed_at >= 6.days.ago.beginning_of_day and renewed_at <= 6.days.ago.end_of_day
    false
  end

  def self.notify_almost_renewable
    Listing.almost_renewable.each { |l| Notifier.ready_to_renew l }
  end

  def renew
    self.renewed_at = Time.now
    self.renewals  += 1
    self
  end

  def publish
    self.published = true
    self
  end

  def unpublish
    self.published = false
    self
  end
  
  def views
    self.impressionist_count :filter => :session_hash
  end

  def to_param
    permalink
  end

  def as_json options={}
    self.attributes.keep_if { |k,v| k != 'id' }
  end

  def self.remove_expired_images
    Listing.expired.each do |listing|
      listing.images.each { |i| i.destroy } # Remove the db entry AND image, so phantom image references are removed
    end
  end
end
