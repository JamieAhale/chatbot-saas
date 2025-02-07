module ApplicationHelper
  def get_plan_name(price_id)
    case price_id
    when ENV['STRIPE_PRICE_LITE_ID']
      'Lite'
    when ENV['STRIPE_PRICE_BASIC_ID']
      'Basic'
    when ENV['STRIPE_PRICE_PRO_ID']
      'Pro'
    else
      'Unknown Plan'
    end
  end
end
