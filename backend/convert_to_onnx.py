"""One-time script to export the PyTorch model to ONNX for Vercel deployment."""
import os

import torch
import torch.nn as nn
from efficientnet_pytorch import EfficientNet

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, 'best_model.pth')
ONNX_PATH = os.path.join(BASE_DIR, 'best_model.onnx')


def main():
    model = EfficientNet.from_pretrained('efficientnet-b0')
    model._fc = nn.Linear(model._fc.in_features, 44)
    state_dict = torch.load(MODEL_PATH, map_location='cpu', weights_only=True)
    model.load_state_dict(state_dict)
    model.eval()

    dummy = torch.randn(1, 3, 300, 300)
    torch.onnx.export(
        model,
        dummy,
        ONNX_PATH,
        input_names=['input'],
        output_names=['output'],
        dynamic_axes={'input': {0: 'batch'}, 'output': {0: 'batch'}},
        opset_version=17,
    )
    print(f'Exported ONNX model to {ONNX_PATH} ({os.path.getsize(ONNX_PATH) / 1e6:.1f} MB)')


if __name__ == '__main__':
    main()
