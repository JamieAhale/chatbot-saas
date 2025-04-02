module ApplicationHelper
  def get_plan_name_from_price_id(price_id)
    case price_id
    when ENV['STRIPE_PRICE_BASIC_ID']
      'Basic'
    when ENV['STRIPE_PRICE_STANDARD_ID']
      'Standard'
    when ENV['STRIPE_PRICE_PRO_ID']
      'Pro'
    when ENV['STRIPE_PRICE_TEST_ID']
      'Test'
    else
      'Unknown Plan'
    end
  end

  def get_price_id_from_plan_name(plan_name)
    case plan_name
    when 'Basic'
      ENV['STRIPE_PRICE_BASIC_ID']
    when 'Standard'
      ENV['STRIPE_PRICE_STANDARD_ID']
    when 'Pro'
      ENV['STRIPE_PRICE_PRO_ID']
    when 'Test'
      ENV['STRIPE_PRICE_TEST_ID']
    else
      nil
    end
  end 
end
