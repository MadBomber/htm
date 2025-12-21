# Class: HTM::ConfigSection
**Inherits:** Object
    

ConfigSection provides method access to nested configuration hashes


**`@example`**
```ruby
section = ConfigSection.new(host: 'localhost', port: 5432)
section.host  # => 'localhost'
section.port  # => 5432
```

# Instance Methods
## [](key) {: #method-i-[] }
## []=(key, value) {: #method-i-[]= }
## each(&block) {: #method-i-each }
## initialize(hash{}) {: #method-i-initialize }
**`@return`** [ConfigSection] a new instance of ConfigSection

## keys() {: #method-i-keys }
## merge(other) {: #method-i-merge }
## method_missing(method, *args, &block) {: #method-i-method_missing }
## respond_to_missing?(method, include_privatefalse) {: #method-i-respond_to_missing? }
**`@return`** [Boolean] 

## to_h() {: #method-i-to_h }