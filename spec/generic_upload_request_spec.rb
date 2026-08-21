RSpec.describe Epics::GenericUploadRequest do
  let(:client) do
    Epics::Client.new(
      File.open(File.join(File.dirname(__FILE__), "fixtures", "SIZBN001.key")), "secret",
      "https://194.180.18.30/ebicsweb/ebicsweb", "SIZBN001", "EBIX", "EBICS",
      version: Epics::Keyring::VERSION_25
    )
  end

  # A payment document the way Nokogiri renders it: one element per line.
  let(:document) { %Q{<?xml version="1.0"?>\r\n<Document>\n  <Amount>670.56</Amount>\n</Document>\n} }

  subject { described_class.new(client, document) }

  describe "#document_digest" do
    # The EBICS spec hashes the document with CR, LF and Ctrl-Z removed. Hashing the
    # raw document yields a signature the bank rejects at verification (HAC DS0B).
    it "is not affected by the line breaks in the document" do
      single_line = described_class.new(client, document.gsub(/[\r\n]/, ""))

      expect(subject.document_digest).to eq(single_line.document_digest)
    end

    it "also removes Ctrl-Z" do
      with_ctrl_z = described_class.new(client, document + "\x1A")

      expect(with_ctrl_z.document_digest).to eq(subject.document_digest)
    end

    # Golden value produced by epics 2.11.0, which did
    # `digester.digest(document.gsub(/\n|\r/, ""))`. Keeps this fork bit-compatible
    # with the released gem for H004, which is what the bank has always accepted.
    it "matches the digest epics 2.11.0 produces for the same document" do
      expect(subject.document_digest.unpack1("H*"))
        .to eq("4d022b3e9fb691e17cb4b13cee215d251b6e7b57a83e95b767974d9e205baef6")
    end
  end
end
