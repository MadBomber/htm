# Class HTM::Railtie <a id="class-HTM-Railtie"></a>

|  |  |
| --- | --- |
| **Inherits** | Rails::Railtie |
| **Defined in** | lib/htm/railtie.rb |

Rails Railtie for automatic HTM configuration in Rails applications

This railtie automatically configures HTM when Rails boots:
*   Sets logger to Rails.logger
*   Sets job backend to :active_job
*   Loads Rake tasks
*   Configures test environment for synchronous jobs

**@example Rails application**
```ruby
# HTM is automatically configured on Rails boot
# No additional setup required
```

**@example Custom configuration**
```ruby
# config/initializers/htm.rb
HTM.configure do |config|
  config.embedding_model = 'custom-model'
  config.tag_model = 'custom-tag-model'
end
```
