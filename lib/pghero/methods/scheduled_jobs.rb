module PgHero
  module Methods
    module ScheduledJobs
      def scheduled_jobs
        select_all <<-SQL
          SELECT * from cron.job
        SQL
      end

      def job_run_details
        select_all <<-SQL
          SELECT * from cron.job_run_details
        SQL
      end
    end
  end
end
