
require 'digest'
require 'sequel'

##
# Tiny Database Patcher.
#
module TDP
  ##
  # Raised when there is a record that patch was applied to
  # the database but the patch itself doesn't exist in the
  # schema configuration.
  #
  class NotConfiguredError < RuntimeError
    ##
    # * *patch_name* is the name of the patch
    #
    def initialize(patch_name)
      super "No configuration file for patch in database: #{patch_name}"
    end
  end

  ##
  # Raised when patch exists in the schema configuration but
  # wasn't applied to the database.
  #
  class NotAppliedError < RuntimeError
    # Problematic patch (a Patch object)
    attr_reader :patch

    ##
    # * *patch* is a problematic patch (a Patch object)
    #
    def initialize(patch)
      super "Patch is not applied: #{patch.name}"
      @patch = patch
    end
  end

  ##
  # Raised when signature of the patch in database doesn't match
  # the signature of the patch in schema configuration.
  #
  class MismatchError < RuntimeError
    # Problematic patch (a Patch object)
    attr_reader :patch

    ##
    # * *patch* is a problematic patch (a Patch object)
    #
    def initialize(patch)
      super "Applied patch doesn't match configuration: #{patch.name}"
      @patch = patch
    end
  end

  ##
  # Raised when schema configuration contains multiple patches
  # with same name and different content.
  #
  class ContradictionError < RuntimeError
    # Contradicting patches (Patch objects)
    attr_reader :patches

    ##
    # * *patches* is a list of problematic patches (Patch objects)
    def initialize(patches)
      super('Patches with same name and different content: ' +
        patches.map(&:full_filename).join(' / ')
      )
      @patches = patches.clone.freeze
    end
  end

  ##
  # A single patch.
  #
  class Patch
    # Content of the patch.
    attr_reader :content

    # Full name of the patch file.
    attr_reader :full_filename

    # SHA-256 hash of content.
    attr_reader :signature

    # Name of the patch.
    attr_reader :name

    ##
    # * *full_filename* is a full path to _.sql_ file
    #
    def initialize(full_filename)
      @full_filename = full_filename
      _, @name = File.split(full_filename)
      @content = File.read(full_filename)
      @signature = Digest::SHA256.hexdigest(@content)
    end

    ##
    # Returns true if patch is volatile.
    #
    def volatile?
      TDP.volatile_patch_file?(@name)
    end

    ##
    # Returns true if patch is permanent.
    #
    def permanent?
      TDP.permanent_patch_file?(@name)
    end

    ##
    # Comparison function. Any permanent patch takes precedence
    # over any volatile one, if both patches are permanent or both
    # are volatile, ordering is based on name.
    #
    def <=>(other)
      return -1 if permanent? && other.volatile?
      return 1 if volatile? && other.permanent?
      @name <=> other.name
    end
  end

  ##
  # A set of patches.
  #
  class PatchSet
    def initialize
      @patches = {}
    end

    ##
    # Adds a patch to the set. Raises ContradictionError in case
    # if patch set already contains a patch with the same name and
    # different content.
    #
    # :arg: patch : Patch
    #
    def <<(patch)
      known_patch = @patches[patch.name]
      if known_patch.nil?
        @patches[patch.name] = patch
      elsif patch.content != known_patch.content
        raise ContradictionError, [known_patch, patch]
      end
    end

    ##
    # Calls the given block once for each patch in collection,
    # passing that element as a parameter.
    #
    # Ordering of the patches is: first, all permanent patches
    # alphanumerically sorted by name, then all volatile patches
    # sorted in the same way.
    #
    def each
      @patches.values.sort.each { |patch| yield patch }
    end

    ##
    # Returns an array of patches for which given block returns
    # a true value.
    #
    # Ordering of patches is same as in #self.each method.
    #
    def select
      @patches.values.sort.select { |patch| yield patch }
    end

    ##
    # Retrieves Patch by name. If there's no patch with this
    # name, returns nil.
    #
    def [](name)
      @patches[name]
    end
  end

  ##
  # Data access object that encapsulates all operations with
  # the database.
  class DAO
    attr_reader :db

    ##
    # Creates a new DAO object.
    #
    # *db* must be one of:
    # * instance of Sequel::Database class
    # * database URL that can be passed to Sequel.connect()
    #
    def initialize(db)
      case db
      when Sequel::Database
        @db = db
      when String
        @db = Sequel.connect(db)
      else
        raise ArgumentError, "Invalid argument #{db} of class #{db.class}"
      end
    end

    ##
    # Initializes database tables for keeping track of applied
    # patches.
    #
    def bootstrap
      return if @db.table_exists?(:tdp_patch)
      @db << %{
        CREATE TABLE tdp_patch(
        name VARCHAR PRIMARY KEY
        , signature VARCHAR NOT NULL
        )
      }
    end

    ##
    # Fetches the information about applied patches and
    # returns it as { name => signature } hash.
    #
    def applied_patches
      result = {}
      @db[:tdp_patch].select(:name, :signature).each do |row|
        result[row[:name]] = row[:signature]
      end
      result
    end

    ##
    # Looks up a signature of a patch by its name.
    #
    def patch_signature(name)
      row = @db[:tdp_patch].select(:signature).where(name: name).first
      row.nil? ? nil : row[:signature]
    end

    ##
    # Applies a patch (a Patch object).
    #
    def apply(patch)
      @db << patch.content
      register(patch)
    rescue Sequel::Error => ex
      raise Sequel::Error,
            "Failed to apply patch #{patch.full_filename}: #{ex}"
    end

    ##
    # Registers a patch (a Patch object) as applied.
    #
    def register(patch)
      q = @db[:tdp_patch].where(name: patch.name)
      if q.empty?
        @db[:tdp_patch].insert(
          name: patch.name,
          signature: patch.signature
        )
      else
        q.update(signature: patch.signature)
      end
    end

    ##
    # Erases all data about applied patches.
    #
    def erase
      @db[:tdp_patch].delete
    end
  end

  ##
  # Main class of the package.
  #
  class Engine
    ##
    # Creates a new Engine object.
    #
    # *db* must be one of:
    # * instance of Sequel::Database class
    # * database URL that can be passed to Sequel.connect()
    #
    def initialize(db)
      @dao = DAO.new(db)
      @patches = PatchSet.new
    end

    ##
    # Registers patch files in the engine.
    #
    # *filename* may be either a name of .sql file or a name
    # of directory (which would be recursively scanned for .sql
    # files)
    #
    def <<(filename)
      if File.directory?(filename)
        Dir.foreach(filename) do |x|
          self << File.join(filename, x) unless x.start_with?('.')
        end
      elsif TDP.patch_file?(filename)
        @patches << Patch.new(filename)
      end
    end

    ##
    # Initializes database tables for keeping track of applied
    # patches.
    #
    def bootstrap
      @dao.bootstrap
    end

    ##
    # Produces an ordered list of patches that need to be applied.
    #
    # May raise MismatchError in case if signatures of any permanent
    # patches that are present in the configuration don't match
    # ones of the patches applied to the database.
    #
    def plan
      @patches.select do |patch|
        signature = @dao.patch_signature(patch.name)
        next false if signature == patch.signature
        next true if signature.nil? || patch.volatile?
        raise MismatchError, patch
      end
    end

    ##
    # Applies all changes that need to be applied.
    #
    def upgrade
      validate_upgradable
      plan.each { |patch| @dao.apply(patch) }
    end

    ##
    # Validates that it is safe run upgrade the database.
    # In particular, the following conditions must be met:
    # * there is an .sql file for every patch that is marked
    #   as applied to database
    # * every permanent patch has same signature as the corresponding
    #   .sql file.
    #
    # May raise MismatchError or NotConfiguredError in case if those
    # conditions aren't met.
    #
    def validate_upgradable
      @dao.applied_patches.each_key do |name|
        raise NotConfiguredError, name unless @patches[name]
      end
      plan
    end

    ##
    # Validates that all patches are applied to the database.
    #
    # May raise MismatchError, NotConfiguredError or NotAppliedError
    # in case if there are any problems.
    #
    def validate_compatible
      validate_upgradable

      @patches.each do |patch|
        signature = @dao.patch_signature(patch.name)
        next if signature == patch.signature
        raise NotAppliedError, patch if signature.nil?
        raise MismatchError, patch
      end
    end

    ##
    # Erases existing data about applied patches and replaces
    # it with configured schema.
    #
    def retrofit
      @dao.erase
      @patches.each do |patch|
        @dao.register(patch)
      end
    end
  end

  ##
  # Returns true if argument is a valid file name of a permanent
  # patch.
  #
  # To qualify for a permanent patch, file name must start with
  # a number and end with ".sql" extension.
  # E.g. _001-initial-schema.sql_ or _201611001_add_accounts_table.sql_
  #
  def self.permanent_patch_file?(filename)
    /^\d+.*\.sql$/ =~ filename
  end

  ##
  # Returns true if argument is a valid file name of a volatile
  # patch.
  #
  # To qualify for a volatile patch, file name must end with ".sql"
  # exception and *NOT* start with a number (otherwise it'd qualify
  # for permanent patch instead). E.g. _views.sql_
  # or _stored-procedures.sql_
  #
  def self.volatile_patch_file?(filename)
    /^[^\d]+.*\.sql$/ =~ filename
  end

  ##
  # Returns true if argument is a valid file name of a patch.
  #
  # To qualify for a patch, file name must end with ".sql"
  # extension.
  #
  def self.patch_file?(filename)
    filename.end_with?('.sql')
  end

  ##
  # Main entrypoint of TDP package.
  #
  # Initializes an Engine with given database details and
  # schema files locations and then calls the given block
  # passing engine as a parameter.
  #
  # *db* must be one of:
  # * instance of Sequel::Database class
  # * database URL that can be passed to Sequel.connect()
  #
  # *paths* must be an array of names of .sql files and directories
  # containing those files
  #
  def self.execute(db, paths = [])
    engine = Engine.new(db)
    paths.each { |x| engine << x }
    engine.bootstrap
    yield engine
  end
end
