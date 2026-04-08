module RequestAuthHelpers
  def sign_in_as(user, password: "password123")
    post user_session_path, params: {
      user: {
        email: user.email,
        password: password
      }
    }
  end
end

RSpec.configure do |config|
  config.include RequestAuthHelpers, type: :request
end
