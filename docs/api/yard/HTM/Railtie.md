# Class: HTM::Railtie
**Inherits:** Rails::Railtie
    

Rails Railtie for automatic HTM configuration in Rails applications

This railtie automatically configures HTM when Rails boots:
*   Sets logger to Rails.logger
*   Sets job backend to :active_job
*   Loads Rake tasks
*   Configures test environment for synchronous jobs


**`@example`**
```ruby
# HTM is automatically configured on Rails boot
# No additional setup required
```
**`@example`**
```ruby
# config/initializers/htm.rb
HTM.configure do |config|
  config.embedding.model = 'custom-model'
  config.tag.model = 'custom-tag-model'
end
```

