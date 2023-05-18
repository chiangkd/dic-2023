import torch
import torch.nn as nn
import numpy as np
import os
import cv2

imgPath = 'images/bleach.png'

def int2bin(number):
    bin = "{:09b}".format(number) + "0000"  # last four bits is 0
    return bin
def float2bin(number):
    intTmp = int(number)
    floTmp = number - intTmp    # remaining floating part
    flo = []
    for i in range(4):  # 4 bit floating point
        floTmp *= 2
        flo += str(int(floTmp)) # do not use append method, otherwise need to deal with "comma"
        floTmp -= int(floTmp)
    flocom = flo
    bin = "{:09b}".format(intTmp) + ''.join(flocom) # append list
    return bin


def layer0out(img_data):
    # padding
    # convolution
    # ReLU

    convWeight = torch.FloatTensor(
        [[[[-0.0625, -0.125, -0.0625], 
         [-0.25, 1, - 0.25],
         [-0.0625, -0.125, -0.0625]]]])
    convBias = torch.FloatTensor([-0.75])

    # torch.nn.Conv2d(in_channels, out_channels, kernel_size, stride=1, padding=0, dilation=1, groups=1, bias=True, padding_mode='zeros', device=None, dtype=None)
    convLayer = nn.Conv2d(in_channels=1, out_channels=1, kernel_size=(3, 3), stride=1, padding=2, dilation=2, padding_mode="replicate")
    convLayer.weight.data = convWeight
    convLayer.bias.data = convBias
    
    layer0 = nn.Sequential(
        convLayer,
        nn.ReLU()
    )
    return layer0(img_data)

def layer1out(img_data):
    layer1 = nn.Sequential(
        nn.MaxPool2d(kernel_size=(2, 2), stride=2)
    )
    return torch.ceil(layer1(img_data))

if __name__ == '__main__':
    img_gray = cv2.imread(imgPath, cv2.IMREAD_GRAYSCALE) # read grayscale image
    img_gray_resize = cv2.resize(img_gray, (64, 64), interpolation=cv2.INTER_AREA)  # resize image
    
    # img.dat
    img_dat_output = []
    for i in range(img_gray_resize.shape[0]):
        for j in range(img_gray_resize.shape[1]):
            img_dat_output.append(str(int2bin(img_gray_resize[i][j])) + " //data " + str(64 * i + j) + ": " + str(img_gray_resize[i][j]) + ".0")
            # print((img_gray_resize[i][j]))
    np.savetxt('./img.dat', img_dat_output, fmt='%s')
    
    # layer0_golden.dat
    img_dat_layer0 = layer0out(torch.FloatTensor(img_gray_resize.reshape(1, 1, 64, 64)))

    layer0_golden_output = []

    for i in range(img_dat_layer0.shape[2]):    # shape = [1, 1, 64, 64]
        for j in range(img_dat_layer0.shape[3]):
            layer0_golden_output.append(str(float2bin(img_dat_layer0.detach().numpy()[0][0][i][j])) + " //data " + str(64 * i + j) + ": " + str(img_dat_layer0.detach().numpy()[0][0][i][j]))
    np.savetxt('./layer0_golden.dat', layer0_golden_output, fmt='%s')

    # layer1_golden.dat
    
    img_dat_layer1 = layer1out(torch.FloatTensor(img_dat_layer0.reshape(1, 1, 64, 64)))

    # print(img_dat_layer0.shape)
    layer1_golden_output = []
    for i in range(img_dat_layer1.shape[2]):    # shape = [1, 1, 32, 32]
        for j in range(img_dat_layer1.shape[3]):
            layer1_golden_output.append(str(float2bin(img_dat_layer1.detach().numpy()[0][0][i][j])) + " //data " + str(32 * i + j) + ": " + str(img_dat_layer1.detach().numpy()[0][0][i][j]))
    np.savetxt('./layer1_golden.dat', layer1_golden_output, fmt='%s')


    ### show image ###
    # cv2.imshow('Image', img_gray_resize)
    # cv2.waitKey(0)
    # cv2.destroyAllWindows()