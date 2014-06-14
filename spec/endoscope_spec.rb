require 'spec_helper'

require 'open3'

describe Endoscope do
  it 'has a version number' do
    expect(Endoscope::VERSION).not_to be nil
  end

  context "with a patient process running the Endoscope agent" do
    let(:bin) { File.expand_path("../../bin", __FILE__) }

    before do
      @patient = IO.popen(File.join(bin, 'patient'))
    end

    after do
      Process.kill "TERM", @patient.pid
    end

    it 'allows an endoscope process to evaluate ruby code inside of a patient process and show the result' do
      q = Queue.new

      Open3.popen2(File.join(bin, 'endoscope')) do |endo_in, endo_out, _endo_wait|
        Thread.new { endo_out.each_line { |l| q.push l.chomp } }

        endo_in.puts "$0"

        Timeout.timeout(5) do
          expect(q.pop).to eql ">> $0" # user input
          expect(q.pop).to eql ">> Sending command $0..."  # command confirmation
          expect(q.pop).to eql "From patient.1 :"          # response banner
          expect(q.pop).to include "endoscope/bin/patient" # response contents
        end
      end
    end
  end

end
