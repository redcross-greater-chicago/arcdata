require 'spec_helper'

describe Scheduler::DirectlineMailer do

  before(:each) do
    @chapter = FactoryGirl.create(:chapter)
    @county1 = FactoryGirl.create :county, chapter: @chapter
    @county2 = FactoryGirl.create :county, chapter: @chapter
    @position = FactoryGirl.create :position, chapter: @chapter
    @people1 = (0..5).map{|i| FactoryGirl.create :person, chapter: @chapter, counties:[@county1], positions: [@position]}
    #@people2 = (0..5).map{|i| FactoryGirl.create :person, counties:[@county2], positions: [@position]}

    @day = FactoryGirl.create :shift_group, chapter: @chapter, start_offset: 7.hours, end_offset: 19.hours
    @night = FactoryGirl.create :shift_group, chapter: @chapter, start_offset: 19.hours, end_offset: 31.hours

    @leadshift = FactoryGirl.create :shift, shift_group: @day, dispatch_role: 1, positions: [@position], county: @county1
    @othershift = FactoryGirl.create :shift, shift_group: @day, positions: [@position], county: @county1

    @leadnight = FactoryGirl.create :shift, shift_group: @night, dispatch_role: 1, positions: [@position], county: @county1
    @othernight = FactoryGirl.create :shift, shift_group: @night, positions: [@position], county: @county1

    @leadass = FactoryGirl.create :shift_assignment, person: @people1.first, date: @chapter.time_zone.today, shift: @leadshift
    FactoryGirl.create :shift_assignment, person: @people1[1], date: @chapter.time_zone.today, shift: @othershift

    @config = Scheduler::DispatchConfig.for_county @county1
    @config.is_active = true
    @config.backup_first = @people1.last
    @config.save!
  end

  let(:mail) { Scheduler::DirectlineMailer.export(@chapter, @chapter.time_zone.today, @chapter.time_zone.today.tomorrow)}
  let(:shift_filename) { "shift_data.csv"}
  let(:roster_filename) { "roster.csv"}

  describe "Support methods" do
    it "Should run when called with force=true" do
      day = @chapter.time_zone.today
      Scheduler::DirectlineMailer.any_instance.should_receive(:export).with(@chapter, day-1, day+60).and_return(stub deliver: true)
      Scheduler::DirectlineMailer.run_for_chapter_if_needed(@chapter)

      @leadass.reload.synced.should == true
    end

    it "Should not run with force=false and all assignments synced" do
      Scheduler::DirectlineMailer.any_instance.should_not_receive(:export)
      Scheduler::DirectlineMailer.run_for_chapter_if_needed(@chapter, false)
    end

    it "Should not run with force=false and an unsynced assignment several days away" do
      @leadass.update_attribute :date, @chapter.time_zone.today+7
      Scheduler::DirectlineMailer.any_instance.should_not_receive(:export)
      Scheduler::DirectlineMailer.run_for_chapter_if_needed(@chapter, false)
    end

    it "Should run with force=false and an unsynced assignment today" do
      @leadass.update_attribute :date, @chapter.time_zone.today
      Scheduler::DirectlineMailer.any_instance.should_receive(:export).and_return(stub deliver: true)
      Scheduler::DirectlineMailer.run_for_chapter_if_needed(@chapter)
    end
  end

  context "Shift Data" do
    it "Should attach the file" do
      mail.attachments[shift_filename].should_not be_nil
    end

    it "should parse as csv" do
      expect {
        CSV.parse(mail.attachments[shift_filename].body.raw_source).should_not be_nil
      }.to_not raise_error
    end

    let (:csv) {CSV.parse(mail.attachments[shift_filename].body.raw_source)}

    it "should include a line for each day/shift group plus header" do
      csv.count.should eq 4 + 1
    end

    it "Should have the on call person plus backups" do
      row = csv[1]
      row[1].should eq (@chapter.time_zone.now.at_beginning_of_day.advance(seconds: @day.start_offset).iso8601)
      row[3..row.count].should =~ [@people1.first.id.to_s, @config.backup_first.id.to_s]
    end

    it "Should have the backups when no on call person" do
      row = csv[3]
      row[1].should eq (@chapter.time_zone.now.at_beginning_of_day.advance(days: 1, seconds: @day.start_offset).iso8601)
      row[3..row.count].should =~ [@config.backup_first.id.to_s]
    end
  end

  context "Person data" do
    it "Should attach the file" do
      mail.attachments[roster_filename].should_not be_nil
    end

    it "should parse as csv" do
      expect {
        CSV.parse(mail.attachments[roster_filename].body.raw_source).should_not be_nil
      }.to_not raise_error
    end

    let (:csv) {CSV.parse(mail.attachments[roster_filename].body.raw_source)}

    it "should have rows for everyone plus header" do
      csv.count.should eq 2 + 1
    end 
  end
  
end