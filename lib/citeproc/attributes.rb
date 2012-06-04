
module CiteProc
  
	# TODO refactor using a Struct instead of a hash. This will have to convert
	# the CiteProc/CSL names which are no proper method names.
	
	
  module Attributes
    extend Forwardable

		FALSE_PATTERN = (/^(false|no|never)$/i).freeze
		
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    def attributes
      @attributes ||= {}
    end
    
		def_delegators :attributes, :length, :empty?

		def [](key)
			attributes[filter_key(key)]
		end
		
		def []=(key, value)
			attributes[filter_key(key)] = filter_value(value)
		end
		
		def filter_key(key)
			key.to_sym
		end
		
		def filter_value(value, key = nil)
			value.respond_to?(:deep_copy) ? value.deep_copy : value.dup
		rescue
			value
		end
		
    def merge(other)
      return self if other.nil?
      
      case other
      when String, /^\s*\{/
        other = MulitJson.decode(other, :symbolize_keys => true)
      when Hash
				# do nothing
      when Attributes
        other = other.to_hash
			else
				raise ParseError, "failed to merge attributes and #{other.inspect}"
      end

      other.each_pair do |key, value|
				attributes[filter_key(key)] = filter_value(value, key)
			end
      
      self
    end

    alias update merge
    
		def reverse_merge(other)
			fail "not implemented yet"
		end

		def to_hash
			attributes.deep_copy
		end

		def to_citeproc
			Hash[*attributes.map { |k,v|
				[k.to_s, v.respond_to?(:to_citeproc) ? v.to_citeproc : v.to_s]
			}.flatten(1)]
		end
		
		def to_json
			MultiJson.encode(to_citeproc)
		end

		# Don't expose internals to public API
		private :filter_key, :filter_value
		
		# initialize_copy should be able to access attributes
    protected :attributes

	
		# def eql?(other)
		# 	case
		# 	when equal?(other)
		# 		true
		# 	when self.class != other.class, length != other.length
		# 		false
		# 	else
		# 		other.attributes.each_pair do |key, value|
		# 			return false unless attributes[key].eql?(value)
		# 		end
		# 		
		# 		true
		# 	end
		# end
		# 
		# def hash
		# end
		
    module ClassMethods

			def create(parameters)
				create!(parameters)
			rescue
				nil
			end

			def create!(parameters)
				new.merge(parameters)
			end

      def attr_predicates(*arguments)
        arguments.flatten.each do |field|
          field, default = *(field.is_a?(Hash) ? field.to_a.flatten : [field]).map(&:to_s)
          attr_field(field, default, true)
        end
      end

      def attr_fields(*arguments)
        arguments.flatten.each do |field|
          attr_field(*(field.is_a?(Hash) ? field.to_a.flatten : [field]).map(&:to_s))
        end
      end
      
      def attr_field(field, default = nil, predicate = false)
        method_id = field.to_s.downcase.gsub(/[-\s]+/, '_')

        unless instance_methods.include?(method_id)
          if default
            define_method(method_id) do
              attributes[field.to_sym]
            end
          else
            define_method(method_id) do
              attributes[field.to_sym] ||= default
            end
          end
        end

        writer_id = [method_id,'='].join
        unless instance_methods.include?(writer_id)
          define_method(writer_id) do |value|
            attributes[field.to_sym] = value
          end
        end
        				
        predicate_id = [method_id, '?'].join  
        if predicate && !instance_methods.include?(predicate_id)
          define_method(predicate_id) do
						v = attributes[field.to_sym]
						!(v.nil? || (v.respond_to?(:empty?) && v.empty?) || v =~ FALSE_PATTERN)
          end
          
          has_predicate = ['has_', predicate_id].join
          alias_method(has_predicate, predicate_id) unless instance_methods.include?(has_predicate)
        end
      end
    
    end
  
  end
end