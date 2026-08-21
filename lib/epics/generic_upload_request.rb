class Epics::GenericUploadRequest < Epics::GenericRequest
  attr_accessor :document
  attr_reader :transaction_key

  def initialize(client, document, **options)
    super(client, **options)
    self.document = document
    aes_factory = Epics::Factories::Crypt::AesFactory.new
    aes = aes_factory.create
    @transaction_key = aes.key
    @crypt_service = Epics::Services::CryptService.new
  end

  # The EBICS spec requires the order document to be hashed with all line break
  # characters (CR, LF, Ctrl-Z) removed. Hashing the raw document produces a
  # signature the bank cannot verify: it answers EBICS_OK on upload and then
  # discards the order at signature verification (HAC DS0B).
  #
  # Strip here rather than in CryptService#hash: the auth signature handler
  # shares that method and must keep hashing the canonicalized header as-is.
  LINE_BREAKS = /[\r\n\x1A]/

  def document_digest
    @crypt_service.hash(document.gsub(LINE_BREAKS, ""))
  end

  def to_transfer_xml
    builder = request_factory.create_transfer_upload(transaction_id, transaction_key, document, 1, true)
    builder.to_xml
  end
end
