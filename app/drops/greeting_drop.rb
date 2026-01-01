class GreetingDrop < BaseDrop
  def initialize(obj = nil)
    @obj = obj
  end

  def time_of_day
    # Get current hour in system timezone (you can customize this to use account timezone)
    current_hour = Time.current.hour

    case current_hour
    when 5..11
      'Good morning'
    when 12..17
      'Good afternoon'
    else
      'Good evening'
    end
  end
end
