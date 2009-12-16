module FriendlyId
  class Tasks
    class << self

      def make_slugs(klass, options = {})
        klass = parse_class_name(klass)
        validate_uses_slugs(klass)
        options = {:limit => 100, :include => :slugs, :conditions => "slugs.id IS NULL"}.merge(options)
        while records = klass.find(:all, options) do
          break if records.size == 0
          records.each do |r|
            r.save!
            yield(r) if block_given?
          end
        end
      end

      def make_slugs_faster(klass, options = {})
        require_ar_extensions

        klass = parse_class_name(klass)
        validate_uses_slugs(klass)
        options = {:limit => 100, :include => :slugs, :conditions => "slugs.id IS NULL"}.merge(options)
        while records = klass.find(:all, options) do
          break if records.size == 0
          slugs = []
          records.each do |r|
            klass.update_all({:cached_slug => r.slug_text}, :id => r.id)
            slug = r.slugs.build :name => r.slug_text
            r.instance_eval do
              if friendly_id_options[:scope]
                scope = send(friendly_id_options[:scope])
                slug.scope = scope.respond_to?(:to_param) ? scope.to_param : scope.to_s
              end
            end
            slug.send :set_sequence
            slugs << slug
            yield(r) if block_given?
          end
          Slug.import slugs, :validate => false
        end
      end

      def delete_slugs_for(klass)
        klass = parse_class_name(klass)
        validate_uses_slugs(klass)
        Slug.destroy_all(["sluggable_type = ?", klass.to_s])
        if klass.cache_column
          klass.update_all("#{klass.cache_column} = NULL")
        end
      end

      def delete_old_slugs(days = nil, class_name = nil)
        days = days.blank? ? 45 : days.to_i
        klass = class_name.blank? ? nil : parse_class_name(class_name.to_s)
        conditions = ["created_at < ?", DateTime.now - days.days]
        if klass
          conditions[0] << " AND sluggable_type = ?"
          conditions << klass.to_s
        end
        slugs = Slug.find :all, :conditions => conditions
        slugs.each { |s| s.destroy unless s.is_most_recent? }
      end

      def parse_class_name(class_name)
        return class_name if class_name.class == Class
        if (class_name.split('::').size > 1)
          class_name.split('::').inject(Kernel) {|scope, const_name| scope.const_get(const_name)}
        else
          Object.const_get(class_name)
        end
      end

      private

      def validate_uses_slugs(klass)
        raise "Class '%s' doesn't use slugs" % klass.to_s unless klass.friendly_id_options[:use_slug]
      end

      def require_ar_extensions
        begin
          require 'ar-extensions/adapters/mysql'
          require 'ar-extensions/import/mysql'
        rescue LoadError
          puts "Please install ar-extensions: gem install ar-etensions"
        end
      end

    end
  end
end
