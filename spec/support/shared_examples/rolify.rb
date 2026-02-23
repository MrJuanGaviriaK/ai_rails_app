RSpec.shared_examples "a rolifiable model" do
  let(:rolifiable) { create(described_class.model_name.singular.to_sym) }

  describe "role assignment" do
    it "can receive a role" do
      rolifiable.add_role(:admin)
      expect(rolifiable.has_role?(:admin)).to be true
    end

    it "can have a role removed" do
      rolifiable.add_role(:admin)
      rolifiable.remove_role(:admin)
      expect(rolifiable.has_role?(:admin)).to be false
    end

    it "can have multiple roles" do
      rolifiable.add_role(:admin)
      rolifiable.add_role(:client)
      expect(rolifiable.has_all_roles?(:admin, :client)).to be true
    end

    it "responds to has_any_role?" do
      rolifiable.add_role(:normal_user)
      expect(rolifiable.has_any_role?(:admin, :normal_user)).to be true
    end
  end
end
