import importlib.util
import io
import unittest
import wave
from pathlib import Path

spec = importlib.util.spec_from_file_location('worker', Path(__file__).resolve().parents[2]/'backend/shazamio_worker.py')
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)

class WorkerTests(unittest.TestCase):
    def wav(self, channels=1, rate=44100, seconds=12):
        data=io.BytesIO()
        with wave.open(data,'wb') as wav:
            wav.setnchannels(channels);wav.setsampwidth(2);wav.setframerate(rate)
            wav.writeframes(b'\0'*(rate*seconds*channels*2))
        return data.getvalue()
    def test_accepts_twelve_second_in_memory_pcm(self):
        self.assertEqual(worker.validate_audio(self.wav()),12)
    def test_rejects_wrong_format_and_short_or_oversized_chunks(self):
        for data in [self.wav(channels=2),self.wav(rate=48000),self.wav(seconds=1),b'x'*(worker.MAX_BYTES+1)]:
            with self.assertRaises(ValueError): worker.validate_audio(data)
    def test_no_match_never_reuses_previous_track(self):
        self.assertEqual(worker.extract_match({'track':{'title':'Song','subtitle':'Artist'},'matches':[]}),{'matched':False})
    def test_preserves_sample_offset_not_request_finish_time(self):
        result=worker.extract_match({'track':{'title':'Song','subtitle':'Artist'},'matches':[{'offset':42.25}]})
        self.assertEqual(result['offset'],42.25)
        self.assertEqual(result['title'],'Song')
    def test_rejects_nonfinite_and_negative_offsets(self):
        for offset in [float('nan'),float('inf'),-1]:
            with self.assertRaises(ValueError): worker.extract_match({'track':{'title':'Song','subtitle':'Artist'},'matches':[{'offset':offset}]})

if __name__=='__main__': unittest.main()
