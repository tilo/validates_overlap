require 'spec_helper'

describe OverlapValidator do
  context 'validation message' do
    it 'should have default message' do
      subject = OverlapValidator.new(attributes: [:starts_at, :ends_at])
      meeting = Meeting.new
      expect(subject).to receive(:overlapped_exists?) { true }
      subject.validate(meeting)
      expect(meeting.errors[:starts_at]).to eq ['overlaps with another record']
    end

    it 'should be possible to configure message' do
      subject = OverlapValidator.new(attributes: [:starts_at, :ends_at])
      meeting = Meeting.new
      expect(subject).to receive(:overlapped_exists?) { true }
      allow(subject).to receive(:options) { { message_title: :optional_key, message_content: 'Message content' } }
      subject.validate(meeting)
      expect(meeting.errors[:optional_key]).to eq ['Message content']
    end

    it 'should be possible to configure multiple keys for message' do
      subject = OverlapValidator.new(attributes: [:starts_at, :ends_at])
      meeting = Meeting.new
      expect(subject).to receive(:overlapped_exists?) { true }
      allow(subject).to receive(:options) { { message_title: [:optional_key_1, 'optional_key_2'], message_content: 'Message content' } }
      subject.validate(meeting)
      expect(meeting.errors[:optional_key_1]).to eq ['Message content']
      expect(meeting.errors[:optional_key_2]).to eq ['Message content']
    end
  end

  context 'deprecation of load_overlapped' do
    it 'warns when a validation is declared with load_overlapped' do
      expect(ValidatesOverlap.deprecator).to receive(:warn).with(/overlapping_records/)
      OverlapValidator.new(attributes: [:starts_at, :ends_at], load_overlapped: true)
    end

    it 'does not warn without load_overlapped' do
      expect(ValidatesOverlap.deprecator).not_to receive(:warn)
      OverlapValidator.new(attributes: [:starts_at, :ends_at])
    end
  end

  context 'initialization' do
    it 'accepts a single attribute (the range-column form)' do
      expect do
        OverlapValidator.new(attributes: [:period])
      end.not_to raise_error
    end

    it 'raises without any attribute' do
      expect do
        OverlapValidator.new(attributes: [])
      end.to raise_error(RuntimeError, 'Validation of time range must be defined by 1 or 2 attributes')
    end

    it 'raises if the time range is defined by more than 2 attributes' do
      expect do
        OverlapValidator.new(attributes: [:starts_at, :ends_at, :deadline_at])
      end.to raise_error(RuntimeError, 'Validation of time range must be defined by 1 or 2 attributes')
    end

    it 'rejects exclude_edges for the range-column form' do
      expect do
        OverlapValidator.new(attributes: [:period], exclude_edges: 'period')
      end.to raise_error(ArgumentError, /not applicable to a range column/)
    end

    it 'rejects shifts for the range-column form' do
      expect do
        OverlapValidator.new(attributes: [:period], start_shift: 1, end_shift: -1)
      end.to raise_error(ArgumentError, /start_shift, end_shift not applicable/)
    end
  end

  context 'range-column form on a non-range column' do
    it 'raises UnsupportedColumnType at validate time' do
      stub_const('ScalarSingleAttribute', Class.new(Meeting) do
        validates :starts_at, overlap: true
      end)
      expect { ScalarSingleAttribute.new.valid? }.to raise_error(OverlapValidator::UnsupportedColumnType, /range column/)
    end
  end
end
