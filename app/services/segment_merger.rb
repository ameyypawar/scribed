class SegmentMerger
  def self.merge(transcription_segments, diarization_segments)
    return transcription_segments if diarization_segments.nil? || diarization_segments.empty?

    transcription_segments.map do |seg|
      seg_start = fetch(seg, :start).to_f
      seg_end   = fetch(seg, :end).to_f
      midpoint  = (seg_start + seg_end) / 2.0

      match = diarization_segments.find do |d|
        d_start = fetch(d, :start).to_f
        d_end   = fetch(d, :end).to_f
        midpoint >= d_start && midpoint <= d_end
      end

      base = seg.respond_to?(:to_h) ? seg.to_h : seg.dup
      base = base.transform_keys(&:to_s)
      base["speaker"] = match ? fetch(match, :speaker) : nil
      base
    end
  end

  def self.fetch(hash, key)
    hash[key.to_s] || hash[key.to_sym]
  end
  private_class_method :fetch
end
