import sys, warnings, os, pickle; warnings.filterwarnings('ignore')
import logging; logging.disable(logging.WARNING)
from basic_pitch.inference import predict
from basic_pitch import ICASSP_2022_MODEL_PATH
mp=os.path.join(os.path.dirname(ICASSP_2022_MODEL_PATH),'nmp.onnx')
on=float(sys.argv[1]); fr=float(sys.argv[2])
for t in sys.argv[3:]:
    out, midi, notes = predict(t+'.mp3', mp, onset_threshold=on, frame_threshold=fr, minimum_note_length=50, minimum_frequency=40, maximum_frequency=3000, multiple_pitch_bends=False, melodia_trick=True)
    pickle.dump((out,notes), open(t+'.bp.pkl','wb'))
    print(t, len(notes))
