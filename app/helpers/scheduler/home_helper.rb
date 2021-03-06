module Scheduler::HomeHelper

  def calendar_month(month, *args)
    scheduler_calendar_path(month.year, month.strftime("%B").downcase, *args)
  end

  def assignments_by_start_date(groups, shifts)
    groups_by_id = groups.group_by(&:id)
    shifts_by_group = shifts.group_by(&:shift_group_id)

    shifts_by_start_date = shifts.group_by{|sh| groups_by_id[sh.shift_group_id].first.start_date}

    date_stub = Squeel::Nodes::Stub.new(:date)
    shift_stub = Squeel::Nodes::Stub.new(:shift_id)
    query = shifts_by_start_date.reduce(nil) do |running_pred, (start_date, shifts_for_date)|

      date_pred = Squeel::Nodes::Predicate.new(date_stub, :eq, start_date)
      group_pred = Squeel::Nodes::Predicate.new(shift_stub, :in, shifts_for_date)
      pred = date_pred & group_pred

      running_pred ? (running_pred | pred) : pred
    end#
    Scheduler::ShiftAssignment.includes{person}.includes{[person.home_phone_carrier, person.cell_phone_carrier, person.work_phone_carrier, person.alternate_phone_carrier, person.sms_phone_carrier]}.where(query)
  end
end
