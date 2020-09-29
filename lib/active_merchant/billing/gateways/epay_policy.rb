require 'json'
require 'base64'
require 'uri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EpayPolicyGateway < Gateway
      self.test_url = "https://api.epaypolicydemo.com/api/v1/"
      self.live_url = "https://api.epaypolicy.com:443/api/v1/"

      self.default_currency = "USD"
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :maestro]
      self.supported_countries = ["US"]
      self.homepage_url = "https://epaypolicy.com"
      self.display_name = "ePayPolicy"

      def initialize(options = {})
        requires!(options, :merchant_id, :private_key, :public_key)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        post[:amount] = amount(money)
        add_payment_details(post, payment, options)
        commit(payment.class == String ? "/transactions/authorize" : "/transactions", post)
      end

      private

      def add_payment_details(post, payment, options)
        if payment.class == String
          puts "Payment will be processed with tokenId #{payment}"
          post[:tokenId] = payment 
        else
          post[:payer] = options[:payer]
          post[:payerFee] = options[:payer_fee] || 0
          post[:comments] = options[:comments] if options[:comments]
          post[:emailAddress] = options[:email] if options[:email]
          card = {}
          card[:cardNumber] = payment.number
          card[:month] = payment.month
          card[:year] = payment.year
          card[:cvc] = payment.cvc
          card[:accountHolder] = "#{payment.first_name} #{payment.last_name}"
          card[:postalCode] = payment.zip
          card[:email] = options[:email] if options[:email]
          post[:creditCardInformation] = card
        end
      end

      def commit(path, params)
        response = api_request(path, params)
        success = response[:error].nil?
        message = (success ? "Transaction succeeded" : response[:error])
        Response.new(
          success,
          message,
          response[:res],
          test: test?,
          error_code: (success ? nil : 'yet_to_be_filled'),
          authorization: (success ? 'yet_to_be_filled' : nil),
        )
      end

      def api_request(path, data)
        raw_response = nil
        begin
          raw_response = ssl_post("#{url}#{path}", data.to_json, headers)
        rescue ResponseError => e
          return {success: false, error: e.to_s}
          # raw_response = e.response.body
        end
        puts "Epay res #{raw_response}"
        return{success: true, res: raw_response}
      end

      def url
        test? ? self.test_url : self.live_url
      end

      def headers
        {
          "authorization" => "Basic " + Base64.encode64(@options[:merchant_id].to_s + ":" + @options[:private_key].to_s).strip,
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "User-Agent" => "ePayPolicy/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
        }
      end

      def handle_response(response)
        body = super(response)
        body = {"header" => response.header.to_hash} if body.empty?
        body
      end
    end
  end
end
