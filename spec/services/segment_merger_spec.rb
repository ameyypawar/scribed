require "rails_helper"

RSpec.describe SegmentMerger do
  it "returns segments unchanged when diarization is empty" do
    segs = [{ "start" => 0.0, "end" => 1.0, "text" => "hi" }]
    expect(described_class.merge(segs, [])).to eq(segs)
  end

  it "tags each segment with the speaker whose interval contains the midpoint" do
    segs = [
      { "start" => 0.0, "end" => 2.0, "text" => "hello" },
      { "start" => 2.0, "end" => 4.0, "text" => "world" }
    ]
    diar = [
      { "speaker" => "SPEAKER_00", "start" => 0.0, "end" => 1.5 },
      { "speaker" => "SPEAKER_01", "start" => 1.5, "end" => 5.0 }
    ]
    result = described_class.merge(segs, diar)
    expect(result[0]["speaker"]).to eq("SPEAKER_00")
    expect(result[1]["speaker"]).to eq("SPEAKER_01")
  end

  it "uses nil speaker when no diarization interval matches" do
    segs = [{ "start" => 10.0, "end" => 12.0, "text" => "lonely" }]
    diar = [{ "speaker" => "SPEAKER_00", "start" => 0.0, "end" => 1.0 }]
    expect(described_class.merge(segs, diar).first["speaker"]).to be_nil
  end

  it "handles symbol-keyed inputs and returns string-keyed hashes" do
    segs = [{ start: 0.0, end: 2.0, text: "hi" }]
    diar = [{ speaker: "SPEAKER_00", start: 0.0, end: 5.0 }]
    out = described_class.merge(segs, diar)
    expect(out.first.keys).to include("start", "end", "text", "speaker")
    expect(out.first["speaker"]).to eq("SPEAKER_00")
  end
end
