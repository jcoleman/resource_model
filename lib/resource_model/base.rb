class ResourceModel::Base

  extend ActiveModel::Callbacks
  extend ActiveModel::Naming
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include ActiveModel::Conversion

  def self.model_name
    ActiveModel::Name.new(self, nil, self.name)
  end

  def self.view_template
    raise NotImplementedError
  end

  def persisted?
    self.respond_to?(:id) && self.id.present?
  end

  @associated_resource_model_attributes = []
  class << self; attr_reader :associated_resource_model_attributes; end

  def self.has_associated_resource_model(attribute_name, options={})
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    if self.associated_resource_model_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains associated resource model named `#{attribute_name}`"
    else
      @associated_resource_model_attributes << attribute_name
      class_name = options[:class_name] || "::#{attribute_name.to_s.camelcase}"
      self.class_eval <<-eos
        attr_reader :#{attribute_name}
        def #{attribute_name}=(model)
          raise ArgumentError, 'Expected instance of `#{class_name}`' unless model.nil? || model.is_a?(#{class_name})
          @#{attribute_name}_attributes = nil
          @#{attribute_name} = model
        end

        def #{attribute_name}_attributes=(attributes)
          if attributes
            model = #{class_name}.new(attributes)
            self.#{attribute_name} = model
          else
            self.#{attribute_name} = nil
          end
          @#{attribute_name}_attributes = attributes
        end

        validate do
          if self.#{attribute_name} && !self.#{attribute_name}.valid?
            self.errors.add(:#{attribute_name}, :invalid)
          end
        end
      eos
    end
  end

  @associated_resource_model_collection_attributes = []
  class << self; attr_reader :associated_resource_model_collection_attributes; end

  def self.has_associated_resource_model_collection(attribute_name, options={})
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    if self.associated_resource_model_collection_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains associated resource model collection named `#{attribute_name}`"
    else
      @associated_resource_model_collection_attributes << attribute_name
      class_name = options[:class_name] || "::#{attribute_name.to_s.singularize.camelcase}"
      self.class_eval <<-eos
        attr_reader :#{attribute_name}
        def #{attribute_name}=(models)
          case models
          when nil
            @#{attribute_name} = []
          when Array
            models.each do |model|
              unless model.is_a?(#{class_name})
                raise ArgumentError, "Assignment of collection to #{attribute_name} contained invalid type \#{model.class.name}; expected only instances of #{class_name}"
              end
            end
            @#{attribute_name} = models
          else
            if models.respond_to?(:to_a)
              self.#{attribute_name} = models.to_a
            else
              raise ArgumentError, 'Expected instance of array'
            end
          end
        end

        def #{attribute_name}_attributes=(attributes={})
          if attributes
            self.#{attribute_name} = attributes.collect do |(k, model_attributes)|
              #{class_name}.new(model_attributes)
            end
          else
            self.#{attribute_name} = []
          end
        end

        validate do
          if !self.#{attribute_name}.inject(true) { |valid, model| model.valid? && valid }
            self.errors.add(:#{attribute_name}, :invalid)
          end
        end
      eos
    end
  end

  @associated_model_attributes = []
  class << self; attr_reader :associated_model_attributes; end

  def self.has_associated_model(attribute_name, options={}) # accepts_nested_attributes: nil
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    if self.associated_model_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains associated model named `#{attribute_name}`"
    else
      @associated_model_attributes << attribute_name
      class_name = options[:class_name] || "::#{attribute_name.to_s.camelcase}"
      self.class_eval <<-eos
        attr_reader :#{attribute_name}, :#{attribute_name}_id
        def #{attribute_name}=(model)
          raise ArgumentError, 'Expected instance of `#{class_name}`' unless model.nil? || model.is_a?(#{class_name})
          @#{attribute_name}_id = model.present? ? model.id : nil
          @#{attribute_name} = model
        end

        def #{attribute_name}_id=(id)
          if id.present?
            scope = #{class_name}.where(id: id)
            eager_loads = #{options[:eager_load].inspect}
            if eager_loads
              scope = scope.eager_load(eager_loads)
            end
            self.#{attribute_name} = scope.first!
          else
            self.#{attribute_name} = nil
          end
        end
      eos
    end
  end

  @associated_model_collection_attributes = []
  class << self; attr_reader :associated_model_collection_attributes; end

  def self.has_associated_model_collection(attribute_name, class_name: nil, unique: true)
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    if self.associated_model_collection_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains associated model collection named `#{attribute_name}`"
    else
      @associated_model_collection_attributes << attribute_name
      class_name ||= "::#{attribute_name.to_s.singularize.camelcase}"
      self.class_eval <<-eos
        attr_reader :#{attribute_name}
        def #{attribute_name}_ids
          self.#{attribute_name}.collect { |model| model.id }
        end

        def #{attribute_name}=(models)
          case models
          when nil
            @#{attribute_name} = []
          when Array
            models.each do |model|
              unless model.is_a?(#{class_name})
                raise ArgumentError, "Assignment of collection to #{attribute_name} contained invalid type \#{model.class.name}; expected only instances of #{class_name}"
              end
            end
            @#{attribute_name} = models
          else
            if models.respond_to?(:to_a)
              self.#{attribute_name} = models.to_a
            else
              raise ArgumentError, 'Expected instance of array'
            end
          end
        end

        def #{attribute_name}_ids=(ids)
          if ids.present?
            ids = ids.collect do |i|
              unless i.is_a?(Integer) || (i.is_a?(String) && i =~ /\\A\\s*\\d+\\s*\\Z/)
                raise ArgumentError, "Assignment of collection to #{attribute_name}_ids contained value (\#{i}) not an integer or stringified integer"
              end
              i.to_i
            end#{unique ? '.uniq' : ''}
            self.#{attribute_name} = #{class_name}.where(id: ids).to_a
          else
            self.#{attribute_name} = []
          end
        end
      eos
    end
  end

  @boolean_attributes = []
  class << self; attr_reader :boolean_attributes; end

  def self.boolean_accessor(attribute_name)
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    if self.boolean_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains a boolean accessor named `#{attribute_name}`"
    else
      @boolean_attributes << attribute_name
      self.class_eval <<-eos
        attr_reader :#{attribute_name}
        def #{attribute_name}=(value)
          case value
          when nil
            @#{attribute_name} = nil
          when TrueClass, FalseClass
            @#{attribute_name} = value
          else
            @#{attribute_name} = value.present? ? ['1', 1, 'true', 't'].include?(value) : nil
          end
        end
      eos
    end
  end

  @integer_attributes = []
  class << self; attr_reader :integer_attributes; end

  def self.integer_accessor(attribute_name)
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    if self.integer_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains a integer accessor named `#{attribute_name}`"
    else
      @integer_attributes << attribute_name
      self.class_eval <<-eos
        attr_reader :#{attribute_name}
        attr_reader :#{attribute_name}_unconverted_value
        def #{attribute_name}=(value)
          @#{attribute_name}_unconverted_value = value
          @#{attribute_name} = value.present? && value.to_s =~ /\\A\\s*\\-?\\d+\\s*\\Z/ ? value.to_i : nil
        end
        validate do
          if self.#{attribute_name}_unconverted_value.present? != self.#{attribute_name}.present?
            self.errors.add(:#{attribute_name}, :not_an_integer)
          end
        end
      eos
    end
  end

  @decimal_attributes = []
  class << self; attr_reader :decimal_attributes; end

  def self.decimal_accessor(attribute_name, options={})
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    if self.decimal_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains a decimal accessor named `#{attribute_name}`"
    else
      decimal_regex = /\A\s*[+-]?\s*\d*(\d,\d)*\d*\.?\d*\s*\Z/
      @decimal_attributes << attribute_name
      self.class_eval <<-eos
        attr_reader :#{attribute_name}
        attr_reader :#{attribute_name}_unconverted_value
        def #{attribute_name}=(value)
          @#{attribute_name}_unconverted_value = value
          @#{attribute_name} = value.present? && value.to_s =~ #{decimal_regex.inspect} ? BigDecimal.new(value.to_s.gsub(/\\s|[,]/, '')) : nil
        end
        validate do
          if self.#{attribute_name}_unconverted_value.present? != self.#{attribute_name}.present?
            self.errors.add(:#{attribute_name}, :not_a_number)
          end
        end
      eos
    end
  end

  @usd_attributes = []
  class << self; attr_reader :usd_attributes; end

  def self.usd_accessor(attribute_name, options={})
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    if self.usd_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains a usd accessor named `#{attribute_name}`"
    else
      usd_regex = /\A\s*[+-]?\s*\$?\s*\d*(\d,\d)*\d*\.?\d*\s*\Z/
      @usd_attributes << attribute_name
      self.class_eval <<-eos
        attr_reader :#{attribute_name}
        attr_reader :#{attribute_name}_unconverted_value
        def #{attribute_name}=(value)
          @#{attribute_name}_unconverted_value = value
          @#{attribute_name} = value.present? && value.to_s =~ #{usd_regex.inspect} ? BigDecimal.new(value.to_s.gsub(/[\$,]|\\s/, '')) : nil
        end
        validate do
          if self.#{attribute_name}_unconverted_value.present? != self.#{attribute_name}.present?
            self.errors.add(:#{attribute_name}, :invalid)
          end
        end
      eos
    end
  end

  @date_attributes = []
  class << self; attr_reader :date_attributes; end

  def self.date_accessor(attribute_name, options={})
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    raise ArgumentError, "Expected options[:timezone]=`#{options[:timezone]}` to be an instance of Symbol, String, or Nil" unless options[:timezone].nil? || options[:timezone].is_a?(String) || options[:timezone].is_a?(Symbol)
    if self.date_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains a date accessor named `#{attribute_name}`"
    else
      @date_attributes << attribute_name
      self.class_eval <<-eos
        attr_reader :#{attribute_name}
        attr_reader :#{attribute_name}_unconverted_value
        def #{attribute_name}=(value)
          case value
          when nil
            @#{attribute_name}_unconverted_value = nil
            @#{attribute_name} = nil
          when Time, DateTime
            @#{attribute_name}_unconverted_value = value
            timezone = #{case options[:timezone]; when Symbol; "self.send(#{options[:timezone].inspect})"; when String; "ActiveSupport::TimeZone[#{options[:timezone].inspect}]"; else; "ActiveSupport::TimeZone['UTC']"; end}
            @#{attribute_name} = ActiveSupport::TimeWithZone.new(nil, timezone, (value.is_a?(ActiveSupport::TimeWithZone) ? value.time : value))
          when String
            @#{attribute_name}_unconverted_value = value
            parsed_date = DateTime.parse(value) rescue nil
            timezone = #{case options[:timezone]; when Symbol; "self.send(#{options[:timezone].inspect})"; when String; "ActiveSupport::TimeZone[#{options[:timezone].inspect}]"; else; "ActiveSupport::TimeZone['UTC']"; end}
            @#{attribute_name} = parsed_date ? ActiveSupport::TimeWithZone.new(nil, timezone, parsed_date) : nil
          else
            raise ArgumentError, 'Unexpected value passed to date_accessor #{attribute_name}; expected Time, String, or nil.'
          end
        end
        validate do
          if self.#{attribute_name}_unconverted_value.present? != self.#{attribute_name}.present?
            self.errors.add(:#{attribute_name}, :invalid)
          end
        end
      eos
    end
  end

  @string_attributes = []
  class << self; attr_reader :string_attributes; end

  def self.string_accessor(attribute_name, options={})
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    if self.string_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains a string accessor named `#{attribute_name}`"
    else
      @string_attributes << attribute_name
      self.class_eval <<-eos
        attr_reader :#{attribute_name}
        def #{attribute_name}=(value)
          if #{options[:strip] == true} && value
            value = value.strip
          end
          value = nil unless value.present?
          @#{attribute_name} = value
        end
      eos
    end
  end

  @enum_attributes = []
  class << self; attr_reader :enum_attributes; end

  def self.enum_accessor(attribute_name, enums:, raise_error_on_set: false, allow_nil: true)
    raise ArgumentError, "Expected `#{attribute_name}` to be an instance of Symbol" unless attribute_name.is_a?(Symbol)
    raise ArgumentError, "Expected `enums`: `#{enums}` to be an instance of Array containing only instances of String" unless enums.is_a?(Array) && enums.all? { |e| e.is_a?(String) }
    raise ArgumentError, "Expected `raise_error_on_set`: `#{raise_error_on_set}` to be an instance of TrueClass or FalseClass" unless raise_error_on_set.is_a?(TrueClass) || raise_error_on_set.is_a?(FalseClass)
    raise ArgumentError, "Expected `allow_nil`: `#{allow_nil}` to be an instance of TrueClass or FalseClass" unless allow_nil.is_a?(TrueClass) || allow_nil.is_a?(FalseClass)

    if self.enum_attributes.include?(attribute_name)
      raise ArgumentError, "Already contains a enum accessor named `#{attribute_name}`"
    else
      @enum_attributes << attribute_name
      self.class_eval <<-eos
        attr_reader :#{attribute_name}
        validates :#{attribute_name}, inclusion: {in: #{(enums + (allow_nil ? [nil] : [])).inspect}}
        def #{attribute_name}=(value)
          value = nil unless value.present?
          if #{raise_error_on_set} && !((#{allow_nil} && value.nil?) || #{enums.inspect}.include?(value))
            raise ArgumentError, 'Expected to receive valid enum string or nil.'
          end
          @#{attribute_name} = value
        end
        def #{attribute_name}_enums
          #{enums.inspect}
        end
      eos
    end
  end

  def self.inherited(klass)
    klass.class_eval <<-eos
      @associated_model_attributes = []
      @associated_model_collection_attributes = []
      @associated_resource_model_attributes = []
      @associated_resource_model_collection_attributes = []
      @boolean_attributes = []
      @integer_attributes = []
      @decimal_attributes = []
      @usd_attributes = []
      @date_attributes = []
      @string_attributes = []
      @enum_attributes = []
    eos
    class << klass
      def associated_model_attributes
        self.superclass.associated_model_attributes + @associated_model_attributes
      end
      def associated_model_collection_attributes
        self.superclass.associated_model_collection_attributes + @associated_model_collection_attributes
      end
      def associated_resource_model_attributes
        self.superclass.associated_resource_model_attributes + @associated_resource_model_attributes
      end
      def associated_resource_model_collection_attributes
        self.superclass.associated_resource_model_collection_attributes + @associated_resource_model_collection_attributes
      end
      def boolean_attributes
        self.superclass.boolean_attributes + @boolean_attributes
      end
      def integer_attributes
        self.superclass.integer_attributes + @integer_attributes
      end
      def decimal_attributes
        self.superclass.decimal_attributes + @decimal_attributes
      end
      def usd_attributes
        self.superclass.usd_attributes + @usd_attributes
      end
      def date_attributes
        self.superclass.date_attributes + @date_attributes
      end
      def string_attributes
        self.superclass.date_attributes + @string_attributes
      end
      def enum_attributes
        self.superclass.date_attributes + @enum_attributes
      end
    end
  end

  def initialize(attributes={})
    self.attributes = attributes
  end

  def attributes=(attributes)
    (
      self.class.associated_resource_model_collection_attributes +
      self.class.associated_model_collection_attributes
    ).each do |attribute|
      unless (value = self.send(attribute)).is_a?(Array) && value.present?
        self.send("#{attribute}=", [])
      end
    end

    if attributes.present?
      attributes = attributes.dup

      (
        self.class.associated_resource_model_attributes +
        self.class.associated_resource_model_collection_attributes
      ).each do |attribute|
        attribute_attributes_key = "#{attribute}_attributes".to_sym
        if attributes.key?(attribute)
          self.send("#{attribute}=", attributes.delete(attribute))
        end
        if attributes.key?(attribute_attributes_key)
          self.send("#{attribute_attributes_key}=", attributes.delete(attribute_attributes_key))
        end
      end

      self.class.associated_model_attributes.each do |attribute|
        id_attribute = "#{attribute}_id".to_sym
        if attributes.key?(attribute)
          self.send("#{attribute}=", attributes.delete(attribute))
          attributes.delete(id_attribute)
        elsif attributes.key?(id_attribute)
          self.send("#{id_attribute}=", attributes.delete(id_attribute))
        end
      end

      self.class.associated_model_collection_attributes.each do |attribute|
        ids_attribute = "#{attribute}_ids"
        if attributes.key?(attribute)
          self.send("#{attribute}=", attributes.delete(attribute))
          attributes.delete(ids_attribute)
        elsif attributes.key?(ids_attribute)
          self.send("#{ids_attribute}=", attributes.delete(ids_attribute))
        end
      end

      attributes.each do |name, value|
        send("#{name}=", value)
      end
    end
  end

  def to_json_attributes
    hash = {}
    self.class.boolean_attributes.each do |attribute_name|
      hash[attribute_name] = self.send(attribute_name)
    end
    self.class.integer_attributes.each do |attribute_name|
      hash[attribute_name] = self.send(attribute_name)
    end
    self.class.decimal_attributes.each do |attribute_name|
      hash[attribute_name] = self.send(attribute_name).andand.to_s
    end
    self.class.usd_attributes.each do |attribute_name|
      hash[attribute_name] = self.send(attribute_name).andand.to_s
    end
    self.class.date_attributes.each do |attribute_name|
      hash[attribute_name] = self.send(attribute_name).andand.iso8601
    end
    self.class.string_attributes.each do |attribute_name|
      hash[attribute_name] = self.send(attribute_name)
    end
    self.class.enum_attributes.each do |attribute_name|
      hash[attribute_name] = self.send(attribute_name)
    end
    self.class.associated_model_attributes.each do |attribute_name|
      id_attribute_name = "#{attribute_name}_id"
      value = self.send(id_attribute_name)
      if value
        hash[id_attribute_name.to_sym] = value
      end
    end
    self.class.associated_model_collection_attributes.each do |attribute_name|
      ids_attribute_name = "#{attribute_name}_ids"
      value = self.send(ids_attribute_name)
      if value
        hash[ids_attribute_name] = value
      end
    end
    self.class.associated_resource_model_attributes.each do |attribute_name|
      value = self.send(attribute_name)
      if value
        hash["#{attribute_name}_attributes".to_sym] = value.to_json_attributes
      end
    end
    self.class.associated_resource_model_collection_attributes.each do |attribute_name|
      hash["#{attribute_name}_attributes".to_sym] = self.send(attribute_name).inject({}) do |sub_hash, item|
        sub_hash[sub_hash.size] = item.to_json_attributes
        sub_hash
      end
    end

    hash
  end

end
