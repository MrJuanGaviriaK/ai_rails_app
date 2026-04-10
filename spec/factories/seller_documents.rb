FactoryBot.define do
  factory :seller_document do
    association :seller
    association :uploaded_by, factory: :user
    kind { "identification" }
    status { "uploaded" }
    metadata { {} }

    after(:build) do |seller_document|
      next if seller_document.file.attached?

      seller_document.file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/sample.pdf")),
        filename: "sample.pdf",
        content_type: "application/pdf"
      )
    end
  end
end
