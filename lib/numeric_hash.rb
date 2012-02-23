require "numeric_hash/version"

# Defines a hash whose values are Numeric or additional nested NumericHashes.
#
# Common arithmetic methods available on Numeric can be called on NumericHash
# to affect all values within the NumericHash at once.
#
class NumericHash < ::Hash

  # Default initial value for hash values when an initial value is unspecified.
  # Integer 0 is used instead of Float 0.0 because it can automatically be
  # converted into a Float when necessary during operations with other Floats.
  DEFAULT_INITIAL_VALUE = 0

  BINARY_OPERATORS = [:+, :-, :*, :/, :%, :**, :&, :|, :^, :div, :modulo, :quo, :fdiv, :remainder]
  UNARY_OPERATORS = [:+@, :-@, :~@, :abs, :ceil, :floor, :round, :truncate]

  # Initialize the NumericHash with an array of initial keys or hash of initial
  # key-value pairs (whose values could also be arrays or hashes).  An optional
  # initial value for initial keys can be specified as well.
  #
  #   NumericHash.new                                     # => { }
  #   NumericHash.new([:a, :b])                           # => { :a => 0, :b => 0 }
  #   NumericHash.new([:c, :d], 1.0)                      # => { :c => 1.0, :d => 1.0 }
  #   NumericHash.new(:e => 2, :f => 3.0)                 # => { :e => 2, :f => 3.0 }
  #   NumericHash.new({ :g => 4, :h => [:i, :j] }, 5.0)   # => { :g => 4, :h => { :i => 5.0, :j => 5.0 } }
  #
  def initialize(initial_contents = nil, initial_value = DEFAULT_INITIAL_VALUE)
    case initial_contents
      when ::Array  then apply_array!(initial_contents, initial_value)
      when ::Hash   then apply_hash!(initial_contents, initial_value)
      else raise ArgumentError.new("invalid initial data: #{initial_contents.inspect}") if initial_contents
    end
  end

  def apply_array!(array, initial_value = DEFAULT_INITIAL_VALUE)
    array.each { |key| self[key] = initial_value }
  end

  def apply_hash!(hash, initial_value = DEFAULT_INITIAL_VALUE)
    hash.each do |key, value|
      self[key] = (value.is_a?(::Array) || value.is_a?(::Hash)) ? NumericHash.new(value, initial_value) : convert_to_numeric(value)
    end
  end

  # Total all values in the hash.
  #
  #   @hash1        # => { :a => 1.0, :b => 2 }
  #   @hash2        # => { :c => 3, :d => { :e => 4, :f => 5} }
  #   @hash1.total  # => 3.0
  #   @hash2.total  # => 12
  #
  def total
    values.map { |value| convert_to_numeric(value) }.sum
  end

  # Compress the hash to its top level values, totaling all nested values.
  #
  #   @hash           # => { :a => 1, :b => { :c => 2.0, d: => 3 } }
  #   @hash.compress  # => { :a => 1, :b => 5.0 }
  #
  def compress
    map_values { |value| convert_to_numeric(value) }
  end

  def compress!
    map_values! { |value| convert_to_numeric(value) }
  end

  # Normalize the total of all hash values to the specified magnitude.  If no
  # magnitude is specified, the hash is normalized to 1.0.
  #
  #   @hash                 # => { :a => 1, :b => 2, :c => 3, :d => 4 }
  #   @hash.normalize       # => { :a => 0.1, :b => 0.2, :c => 0.3, :d => 0.4 }
  #   @hash.normalize(120)  # => { :a => 12.0, :b => 24.0, :c => 36.0, :d => 48.0 }
  #
  def normalize(magnitude = 1.0)
    norm_factor = magnitude / total.to_f
    norm_factor = 0.0 unless norm_factor.finite?  # If total was zero, the normalization factor will not be finite; set it to zero in this case.
    map_values { |value| value * norm_factor }
  end

  # Shortcuts to normalize the hash to various totals.
  #
  def to_ratio
    normalize(1.0)
  end

  def to_percent
    normalize(100.0)
  end

  def to_amount(amount)
    normalize(amount)
  end

  # Returns the key-value pair with the smallest compressed value in the hash.
  #
  def min
    compressed_key_values_sorted.first
  end

  # Returns the key-value pair with the largest compressed value in the hash.
  #
  def max
    compressed_key_values_sorted.last
  end
  
  # *DEPRECATED* This method is deprecated. Consider using #map_numeric to
  # perform the same function.
  #
  # Set all negative values in the hash to zero.
  #
  #   @hash                   # => { :a => -0.6, :b => 1.2, :c => 0.4 }
  #   @hash.ignore_negatives  # => { :a => 0.0, :b => 1.2, :a => 0.4 }
  #
  def ignore_negatives
    warn "DEPRECATION WARNING: This method is deprecated. Consider using #map_numeric to perform the same function. Called from: #{caller.first}"
    convert_negatives_to_zero(self)
  end

  # *DEPRECATED* This method is deprecated. Consider using #compress with
  # #reject_numeric to perform the same function.
  #
  # Strips out any zero valued asset classes.
  #
  #   @hash             # => {:a => 0.0, :b => 0.0, :c => 0.8, :d => 0.15, :e => 0.05, :f => 0.0, :g => 0.0, :h => 0.0, :i => 0.0}
  #   @hash.strip_zero  # => {:c => 0.8, :e => 0.05, :d => 0.15}
  #
  def strip_zero
    warn "DEPRECATION WARNING: This method is deprecated. Consider using #compress with #reject_numeric to perform the same function. Called from: #{caller.first}"
    # TODO: Previous version of the code only retained values > 0.0, so the refactored code below retains this behavior; verify whether this is still desired.
    compress.select_values! { |value| value > 0.0 }
  end

  # Define arithmetic operators that apply a Numeric or another NumericHash to
  # the hash.  A Numeric argument is applied to each value in the hash.
  # Hash values of a NumericHash argument are applied to each corresponding
  # value in the hash.  In the case of no such corresponding value, the
  # hash value of the argument is applied to DEFAULT_INITIAL_VALUE.
  #
  #   @hash1            # => { :a => 1.0, :b => 2 }
  #   @hash2            # => { :a => 3, :c => 4 }
  #   @hash1 + @hash2   # => { :a => 4.0, :b => 2, :c => 4 }
  #   @hash1 * 5        # => { :a => 5.0, :b => 10 }
  #
  BINARY_OPERATORS.each do |operator|
    define_method(operator) do |arg|
      if arg.is_a?(NumericHash)
        # Copy the hash into a new initial hash that will be used to return the
        # result and reconcile its traits with those of the argument.
        initial = self.copy.reconcile_traits_with!(arg)

        # Apply the argument to the initial hash.
        arg.inject(initial) do |hash, (arg_key, arg_value)|
          hash[arg_key] = apply_operator_to_values(operator, hash[arg_key], arg_value)
          hash
        end
      else
        map_values { |value| value.__send__(operator, convert_to_numeric(arg)) }
      end
    end
  end

  # Define unary operators that apply to each value in the hash.
  #
  #   @hash         # => { :a => 1.0, :b => -2.5 }
  #   -@hash        # => { :a => -1.0, :b => 2.5 }
  #   @hash.round   # => { :a => 1, :b => -3 }
  #
  UNARY_OPERATORS.each do |operator|
    define_method(operator) { map_values(&operator) }
  end

  # Define conversion methods that convert each value in the hash.
  #
  #   @hash           # => { :a => 1.0, :b => 2 }
  #   @hash.map_to_i  # => { :a => 1, :b => 2 }
  #
  [:to_f, :to_i, :to_int].each do |convert_method|
    define_method("map_#{convert_method}".to_sym) { map_values(&convert_method) }
  end

  # Maps each numeric value using the specified block.
  #
  #   @hash                                     # => { :a => 1, :b => { :c => 2, :d => 3 } }
  #   @hash.map_numeric { |value| "X" * value } # => { :a => "X", :b => { :c => "XX", :d => "XXX" } }
  #   @hash.collect_numeric(&:to_s)             # => { :a => "1", :b => { :c => "2", :d => "3" } }
  #
  def collect_numeric(&block)
    # First attempt to map into a NumericHash.
    map_values do |value|
      if value.is_a?(NumericHash)
        result = value.collect_numeric(&block)
      else
        result = yield(value)

        # If the mapped value not Numeric, abort so that we try again by
        # mapping into a regular Hash.
        raise TypeError.new("result is not Numeric: #{result.inspect}") unless result.is_a?(Numeric)
      end
      result
    end
  rescue TypeError
    # At least one of the values mapped into a non-Numeric result; map into a
    # regular Hash instead.
    map_to_hash do |key, value|
      [key, value.is_a?(NumericHash) ? value.collect_numeric(&block) : yield(value) ]
    end
  end
  alias_method :map_numeric, :collect_numeric

  def collect_numeric!(&block)
    map_values! do |value|
      if value.is_a?(NumericHash)
        result = value.collect_numeric!(&block)
      else
        result = yield(value)

        # If the mapped value not Numeric, abort since we can't change a
        # NumericHash into a regular Hash.
        raise TypeError.new("result is not Numeric: #{result.inspect}") unless result.is_a?(Numeric)
      end
      result
    end
  end
  alias_method :map_numeric!, :collect_numeric!

  # Rejects each numeric value for which the specified block evaluates to true.
  # Any nested hashes that become empty during this procedure are also
  # rejected.
  #
  #   @hash                                       # => { :a => 1, :b => 0.0, :c => { :d => 0, :e => -2 }, :f => { :g => 0.0 } }
  #   @hash.reject_numeric(&:zero?)               # => { :a => 1, :c => { :e => -2 } }
  #   @hash.reject_numeric { |value| value <= 0 } # => { :a => 1 }
  #
  def reject_numeric(&block)
    inject_into_empty do |hash, (key, value)|
      if value.is_a?(NumericHash)
        rejected = value.reject_numeric(&block)
        hash[key] = rejected unless rejected.empty?
      elsif !yield(value)
        hash[key] = value
      end
      hash
    end
  end

  def reject_numeric!(&block)
    reject_values! do |value|
      if value.is_a?(NumericHash)
        value.reject_values!(&block)
        value.empty?
      else
        yield(value)
      end
    end
  end

  # Selects each numeric value for which the specified block evaluates to true.
  # Any nested hashes with no selected values will not be included.
  #
  #   @hash                                       # => { :a => 1, :b => 0.0, :c => { :d => 0, :e => -2 }, :f => { :g => 0.0 } }
  #   @hash.select_numeric(&:zero?)               # => { :b => 0.0, :c => { :d => 0 }, :f => { :g => 0.0 } }
  #   @hash.select_numeric { |value| value <= 0 } # => { :b => 0.0, :c => { :d => 0, :e => -2 }, :f => { :g => 0.0 } }
  #
  def select_numeric
    reject_numeric { |value| !yield(value) }
  end

  def select_numeric!
    reject_numeric! { |value| !yield(value) }
  end

  # Performs a merge with another hash while recursively merging any nested
  # hashes. If true is specified as a second argument, the merge will ensure
  # that the key structure of the other hash is a subset of the structure of
  # the hash.
  #
  #   @hash1                            # => { :a => 1, :b => { :c => 2 } }
  #   @hash2                            # => { :b => 3 }
  #   @hash3                            # => { :d => 4 }
  #   @hash1.deep_merge(@hash2)         # => { :a => 1, :b => 3 }
  #   @hash1.deep_merge(@hash2, true)   # raises TypeError
  #   @hash1.deep_merge(@hash3)         # => { :a => 1, :b => { :c => 2 }, :d => 4 }
  #   @hash1.deep_merge(@hash3, true)   # raises TypeError
  #
  def deep_merge(other_hash, match_structure = false)
    raise ArgumentError.new('hash must be specified') unless other_hash.is_a?(::Hash)
    raise TypeError.new('structure of specified hash is incompatible') if match_structure && !compatible_structure?(other_hash)

    other_hash.inject(self.copy) do |hash, (key, value)|
      hash[key] = if hash[key].is_a?(NumericHash) && value.is_a?(::Hash)
                    hash[key].deep_merge(value, match_structure)
                  else
                    sanitize_numeric_hash_value(value)
                  end
      hash
    end
  end

  def deep_merge!(other_hash, match_structure = false)
    raise ArgumentError.new('hash not specified') unless other_hash.is_a?(::Hash)
    raise TypeError.new('structure of specified hash is incompatible') if match_structure && !compatible_structure?(other_hash)

    other_hash.each do |key, value|
      if self[key].is_a?(NumericHash) && value.is_a?(::Hash)
        self[key].deep_merge!(value, match_structure)
      else
        self[key] = sanitize_numeric_hash_value(value)
      end
    end
    self
  end

  # Converts the NumericHash into a regular Hash.
  #
  def to_hash
    map_to_hash do |key, value|
      [key, value.is_a?(NumericHash) ? value.to_hash : value]
    end
  end

protected  

  # Helper method for converting negative values to zero.
  #
  def convert_negatives_to_zero(value)
    if value.is_a?(NumericHash)
      # Map this method call over all values in the hash.
      value.map_values(&method(__method__))
    else
      value = convert_to_numeric(value)
      value < 0.0 ? 0.0 : value
    end
  end

  # Helper method for converting a specified value to a Numeric.
  #
  def convert_to_numeric(value)
    case
      when value.is_a?(NumericHash)   then value.total
      when value.is_a?(Numeric)       then value
      when value.nil?                 then DEFAULT_INITIAL_VALUE
      when value.respond_to?(:to_f)   then value.to_f
      when value.respond_to?(:to_i)   then value.to_i
      when value.respond_to?(:to_int) then value.to_int
      else raise TypeError.new("cannot convert to Numeric: #{value.inspect}")
    end
  end

  # Helper method for sanitizing a value to be placed into a NumericHash.
  #
  def sanitize_numeric_hash_value(value)
    case value
      when NumericHash  then value
      when Hash         then NumericHash.new(value)
      else convert_to_numeric(value)
    end
  end

  # Helper method for applying an operator to two values of types Numeric
  # and/or NumericHash.
  #
  def apply_operator_to_values(operator, value1, value2)
    if value1.is_a?(NumericHash)
      # First value is a NumericHash; directly apply the second value to it.
      value1.__send__(operator, value2)
    else
      # First value is (or can be converted into) a Numeric
      value1 = convert_to_numeric(value1)
      if value2.is_a?(NumericHash)
        # Second value is a NumericHash; each of its Numeric values should be
        # applied to the first value.
        value2.map_numeric { |value2_sub_value| value1.__send__(operator, value2_sub_value) }
      else
        # Second value also is (or can be converted into) a Numeric; apply the
        # two values directly.
        value1.__send__(operator, convert_to_numeric(value2))
      end
    end
  end

  # Helper method for sorting the compressed version of the hash.
  #
  def compressed_key_values_sorted
    compress.sort_by { |key, value| value }
  end

  # Helper method that determines whether the structure of the specified hash
  # is a subset of the structure of the hash.
  #
  def compatible_structure?(other_hash)
    other_hash.all? do |key, value|
      self.has_key?(key) && (
        (!value.is_a?(::Hash) && !self[key].is_a?(NumericHash)) ||
        (value.is_a?(::Hash) && self[key].is_a?(NumericHash) && self[key].compatible_structure?(value))
      )
    end
  end

  # Helper method for reconciling traits from another hash when a binary
  # operation is performed with that hash.
  #
  def reconcile_traits_with!(hash)
    # There are no traits to reconcile in the base NumericHash.
    self
  end

  class << self

    # Sums an array of NumericHashes, taking into account empty arrays.
    #
    #   @array        # => [ { :a => 1.0, :b => 2 }, { :a => 3, :c => 4 } ]
    #   sum(@array)   # => { :a => 4.0, :b => 2, :c => 4 }
    #   sum([])       # => { }
    #
    def sum(array)
      array.empty? ? self.new : array.sum
    end

  end

end
