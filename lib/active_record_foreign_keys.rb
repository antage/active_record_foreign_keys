require "active_record"

module ActiveRecord
  module ConnectionAdapters
    class TableDefinition
      def references_with_foreign_key(*args)
        options = args.extract_options!
        cols = args.dup
        fk_options = options.delete(:foreign_key) || false
        references_without_foreign_key(*(args << options))
        unless options[:polymorphic] || fk_options == false
          @table_statements ||= []
          fk_options = {} unless fk_options.is_a?(Hash)
          cols.each do |col|
            @table_statements << @base.foreign_key_sql(@table_name, "#{col}_id", col.to_s.pluralize, "id", fk_options)
          end
        end
      end
      alias_method_chain :references, :foreign_key

      def to_sql_with_foreign_key
        col_defs = to_sql_without_foreign_key
        if @table_statements.is_a?(Array) && @table_statements.size > 0
          sql = col_defs + ", " + (@table_statements * ", ")
        else
          sql = col_defs
        end
        sql
      end
      alias_method_chain :to_sql, :foreign_key
    end

    class Table
      def references_with_foreign_key(*args)
        options = args.extract_options!
        cols = args.dup
        fk_options = options.delete(:foreign_key) || false
        references_without_foreign_key(*(args << options))
        unless options[:polymorphic] || fk_options == false
          fk_options = {} unless fk_options.is_a?(Hash)
          cols.each { |col| @base.add_foreign_key(@table_name, "#{col}_id", col.to_s.pluralize, "id", fk_options) }
        end
      end
      alias_method_chain :references, :foreign_key
    end

    module SchemaStatements
      def add_foreign_key(table_name, column_name, reference_table_name, reference_column_name, options = {})
        sql = <<-EOS
          ALTER TABLE #{quote_table_name(table_name)}
            ADD CONSTRAINT #{quote_table_name(foreign_key_constraint_name(table_name, column_name))}
        EOS
        sql += foreign_key_sql(table_name, column_name, reference_table_name, reference_column_name, options)
        execute sql
      end

      def remove_foreign_key(table_name, column_name)
        if foreign_key_exists?(table_name, column_name)
          execute "ALTER TABLE #{quote_table_name(table_name)} DROP CONSTRAINT #{quote_table_name(foreign_key_constraint_name(table_name, column_name))}"
        end 
      end

      def foreign_key_sql(table_name, column_name, reference_table_name, reference_column_name, options = {})
        options = {
          :on_update => :no_action,
          :on_delete => :no_action
        }.merge(options)

        "FOREIGN KEY (#{quote_column_name(column_name)}) REFERENCES #{quote_table_name(reference_table_name)}(#{quote_column_name(reference_column_name)}) ON UPDATE #{foreign_key_action(options[:on_update])} ON DELETE #{foreign_key_action(options[:on_delete])}"
      end

      private

        def foreign_key_constraint_name(table_name, column_name)
          "#{table_name}_#{column_name}_fkey"
        end

        def foreign_key_exists?(table_name, column_name)
          count = select_value("SELECT COUNT(*) FROM pg_constraint WHERE conname = #{quote(foreign_key_constraint_name(table_name, column_name))}")
          count.to_i > 0
        end

        def foreign_key_action(action)
          case action
          when :no_action then "NO ACTION"
          when :restrict then "RESTRICT"
          when :cascade then "CASCADE"
          when :set_null then "SET NULL"
          when :set_default then "SET DEFAULT"
          else
            raise ArgumentError, "Invalid action type. Valid actions are :on_update can be :no_action, :restrict, :cascade, :set_null, :set_default"
          end
        end
    end
  end
end
