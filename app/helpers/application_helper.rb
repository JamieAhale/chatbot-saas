module ApplicationHelper
  def get_plan_name_from_price_id(price_id)
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

  def get_price_id_from_plan_name(plan_name)
    case plan_name
    when 'Lite'
      ENV['STRIPE_PRICE_LITE_ID']
    when 'Basic'
      ENV['STRIPE_PRICE_BASIC_ID']
    when 'Pro'
      ENV['STRIPE_PRICE_PRO_ID']
    else
      nil
    end
  end 
end
