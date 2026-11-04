import sys, warnings; warnings.filterwarnings('ignore')
import logging; logging.disable(logging.WARNING)
from basic_pitch.inference import predict
from basic_pitch import ICASSP_2022_MODEL_PATH
import os
mp=os.path.join(os.path.dirname(ICASSP_2022_MODEL_PATH),'nmp.onnx')
for t in sys.argv[1:]:
    out, midi, notes = predict(t+'.mp3', mp)
    midi.write(t+'.mid')
    print(t, len(notes))
