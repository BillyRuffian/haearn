# Base class for all Active Record models
# All models inherit from this instead of ActiveRecord::Base
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
