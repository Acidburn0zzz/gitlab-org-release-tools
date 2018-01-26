require 'spec_helper'

require 'slack_webhook'

describe SlackWebhook do
  CI_SLACK_WEBHOOK_URL = 'http://foo.slack.com'.freeze
  CI_JOB_ID = '42'.freeze

  let(:channel) { '#ce-to-ee' }
  let(:text) { 'Hello!' }
  let(:response_class) { Struct.new(:code) }
  let(:response) { response_class.new(200) }

  let(:merge_request) do
    double(url: 'http://gitlab.com/mr',
           to_reference: '!123',
           conflicts: nil,
           created_at: Time.new(2018, 1, 4, 6))
  end

  around do |ex|
    ClimateControl.modify CI_SLACK_WEBHOOK_URL: CI_SLACK_WEBHOOK_URL, CI_JOB_ID: CI_JOB_ID do
      Timecop.freeze(Time.new(2018, 1, 4, 8, 30, 42)) do
        ex.run
      end
    end
  end

  describe '.new_merge_request' do
    it 'posts a message' do
      expect(HTTParty)
        .to receive(:post)
          .with(
            CI_SLACK_WEBHOOK_URL,
            { body: { text: "Created a new merge request <#{merge_request.url}|#{merge_request.to_reference}>" }.to_json })
          .and_return(response)

      described_class.new_merge_request(merge_request)
    end

    it 'posts the number of conflicts in the message' do
      merge_request = double(url: 'http://gitlab.com/mr',
                             to_reference: '!123',
                             created_at: Time.new(2018, 1, 4, 6),
                             conflicts: %i[a b c])
      expect(HTTParty)
        .to receive(:post)
          .with(
            CI_SLACK_WEBHOOK_URL,
            { body: { text: "Created a new merge request <#{merge_request.url}|#{merge_request.to_reference}> with #{merge_request.conflicts.count} conflicts! :warning:" }.to_json })
          .and_return(response)

      described_class.new_merge_request(merge_request)
    end
  end

  describe '.existing_merge_request' do
    it 'posts a message' do
      expect(HTTParty)
        .to receive(:post)
          .with(
            CI_SLACK_WEBHOOK_URL,
            { body: { text: "Tried to create a new merge request but <#{merge_request.url}|#{merge_request.to_reference}> from 2 hours ago is still pending! :hourglass:" }.to_json })
          .and_return(response)

      described_class.existing_merge_request(merge_request)
    end
  end

  describe '.missing_merge_request' do
    it 'posts a message' do
      expect(HTTParty)
        .to receive(:post)
          .with(
            CI_SLACK_WEBHOOK_URL,
            { body: { text: "The latest upstream merge MR could not be created! Please have a look at <https://gitlab.com/gitlab-org/release-tools/-/jobs/#{CI_JOB_ID}>. :boom:" }.to_json })
          .and_return(response)

      described_class.missing_merge_request
    end
  end

  describe '.downstream_is_up_to_date' do
    it 'posts a message' do
      expect(HTTParty)
        .to receive(:post)
          .with(
            CI_SLACK_WEBHOOK_URL,
            { body: { text: "EE is already up-to-date with CE. No merge request was created. :tada:" }.to_json })
          .and_return(response)

      described_class.downstream_is_up_to_date
    end
  end

  describe '#fire_hook' do
    context 'when channel is not given' do
      before do
        expect(HTTParty)
          .to receive(:post)
            .with(
              CI_SLACK_WEBHOOK_URL,
              { body: { text: text }.to_json })
            .and_return(response)
      end

      it 'posts to the given url with the given arguments' do
        subject.fire_hook(text: text)
      end

      context 'when response is not successfull' do
        let(:response) { response_class.new(400) }

        it 'prepends the channel with #' do
          expect do
            subject.fire_hook(text: text)
          end.to raise_error(described_class::CouldNotPostError)
        end
      end
    end

    context 'when channel is given' do
      before do
        expect(HTTParty)
          .to receive(:post)
            .with(
              CI_SLACK_WEBHOOK_URL,
              { body: { text: text, channel: channel }.to_json })
            .and_return(response)
      end

      it 'passes the given channel' do
        subject.fire_hook(channel: channel, text: text)
      end
    end
  end
end
