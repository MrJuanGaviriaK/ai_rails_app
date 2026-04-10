require "stringio"

namespace :active_storage do
  namespace :r2 do
    desc "Backfill blobs from SOURCE_SERVICE (default: local) to TARGET_SERVICE (default: r2)"
    task backfill: :environment do
      source_service_name = ENV.fetch("SOURCE_SERVICE", "local")
      target_service_name = ENV.fetch("TARGET_SERVICE", "r2")
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "false"))

      source_service = ActiveStorage::Blob.services.fetch(source_service_name)
      target_service = ActiveStorage::Blob.services.fetch(target_service_name)

      total = ActiveStorage::Blob.count
      copied = 0
      skipped = 0
      failed = 0

      Rails.logger.info("[active_storage:r2:backfill] start total=#{total} source=#{source_service_name} target=#{target_service_name} dry_run=#{dry_run}")

      ActiveStorage::Blob.find_each.with_index(1) do |blob, index|
        if target_service.exist?(blob.key)
          skipped += 1
          next
        end

        if dry_run
          Rails.logger.info("[active_storage:r2:backfill] dry_run missing key=#{blob.key} id=#{blob.id}")
          next
        end

        payload = source_service.download(blob.key)

        target_service.upload(
          blob.key,
          StringIO.new(payload),
          checksum: blob.checksum,
          filename: blob.filename,
          content_type: blob.content_type,
          disposition: blob.content_disposition,
          custom_metadata: blob.custom_metadata
        )

        copied += 1

        if (index % 100).zero?
          Rails.logger.info("[active_storage:r2:backfill] progress index=#{index} copied=#{copied} skipped=#{skipped} failed=#{failed}")
        end
      rescue StandardError => error
        failed += 1
        Rails.logger.error("[active_storage:r2:backfill] error id=#{blob.id} key=#{blob.key} error=#{error.class}: #{error.message}")
      end

      Rails.logger.info("[active_storage:r2:backfill] done total=#{total} copied=#{copied} skipped=#{skipped} failed=#{failed}")
      abort("Backfill completed with failures: #{failed}") if failed.positive?
    end
  end
end
