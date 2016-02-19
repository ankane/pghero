module PgHero
  module Methods
    module System
      def cpu_usage
        rds_stats("CPUUtilization")
      end

      def connection_stats
        rds_stats("DatabaseConnections")
      end

      def replication_lag_stats
        rds_stats("ReplicaLag")
      end

      def read_iops_stats
        rds_stats("ReadIOPS")
      end

      def write_iops_stats
        rds_stats("WriteIOPS")
      end

      def rds_stats(metric_name)
        if system_stats_enabled?
          client =
            if defined?(Aws)
              Aws::CloudWatch::Client.new(access_key_id: access_key_id, secret_access_key: secret_access_key)
            else
              AWS::CloudWatch.new(access_key_id: access_key_id, secret_access_key: secret_access_key).client
            end

          now = Time.now
          resp = client.get_metric_statistics(
            namespace: "AWS/RDS",
            metric_name: metric_name,
            dimensions: [{name: "DBInstanceIdentifier", value: db_instance_identifier}],
            start_time: (now - 1 * 3600).iso8601,
            end_time: now.iso8601,
            period: 60,
            statistics: ["Average"]
          )
          data = {}
          resp[:datapoints].sort_by { |d| d[:timestamp] }.each do |d|
            data[d[:timestamp]] = d[:average]
          end
          data
        else
          {}
        end
      end

      def system_stats_enabled?
        !!((defined?(Aws) || defined?(AWS)) && access_key_id && secret_access_key && db_instance_identifier)
      end

      def access_key_id
        ENV["PGHERO_ACCESS_KEY_ID"] || ENV["AWS_ACCESS_KEY_ID"]
      end

      def secret_access_key
        ENV["PGHERO_SECRET_ACCESS_KEY"] || ENV["AWS_SECRET_ACCESS_KEY"]
      end

      def db_instance_identifier
        databases[current_database].db_instance_identifier
      end
    end
  end
end
