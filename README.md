# Generating JPG + Gain Map HDR Photos Compatible with iPhones/Macs Photos

## Background

With the growing popularity of HDR displays, giants in the industry are placing more emphasis on the editing and exporting of HDR photos. For instance, the latest versions of ACR and Photoshop allow users to edit HDR photos and export them in AVIF format. These photos can then be viewed on iPhones or other devices equipped with HDR displays. However, this method has its limitations. To properly view AVIF files, one would need at least iOS 17, and there is no control over how the photo appears on SDR displays, which can result in images that look washed out, overly green, or even bizarrely colorful when viewed on an SDR screen. Additionally, even with iOS 17, the iPhone's Photos app can encounter bugs when rendering AVIF files, such as crashing or displaying pixelated images when zooming in.

An alternative method involves using [an SDR image with a gain map](https://helpx.adobe.com/camera-raw/using/gain-map.html) to create an HDR photo format, which is an open standard proposed by Adobe and Google. This technique offers more control over the appearance of images in both SDR and HDR formats and boasts better compatibility across various devices and browsers. Consequently, this method is garnering significant interest from both the community and enterprises. However, it is not yet supported on iPhones, which use a slightly different standard based on a grayscale gain map, as opposed to the RGB gamma map suggested by Adobe.

At this year's WWDC, Apple provided [more technical details](https://developer.apple.com/documentation/appkit/images_and_pdf/applying_apple_hdr_effect_to_your_photos) about the gain map and associated metadata. They explained how to extract the gain map from a photo taken with an iPhone, but the process of generating a JPEG file with a gain map that renders with an HDR effect on the iPhone remains unclear. 

This topic has garnered significant interest over several years, leading to extensive discussions and explorations. A notable example is [this thread](https://gist.github.com/kiding/fa4876ab4ddc797e3f18c71b3c2eeb3a) where an [undocumented private API](https://gist.github.com/kiding/fa4876ab4ddc797e3f18c71b3c2eeb3a?permalink_comment_id=4185058#gistcomment-4185058) was utilized alongside specific tricks with private maker-specific EXIF tags. This method allowed people to embed the gain map into a JPEG file, resulting in the only open-source solution that works, to my knowledge.

This repo, which solely relies on public APIs for gain map extraction and embedding, was greatly inspired by all the discussions in the thread and across the internet. Despite the presence of magic numbers in the code, this method successfully overcame three limitations of the already great open source solution:

1. Using an undocumented API is risky as it may not be reliable or supported in the future. The API appears simple, even looks a debugging tool, raising concerns about its longevity.
2. The HDR images created have limitations; they display correctly on an iPhone but are not recognized by the Mac Photos app. This issue might stem from how the private API interacts with the EXIF tags, as evidenced by the [Adobe demo app](https://helpx.adobe.com/camera-raw/using/gain-map.html) identifying the images as SDR, complicating debugging and visualization. 
3. A consistent and flexible workflow would be ideal for addressing this challenge in a systematic way.

On the contrary, the resulting HDR image from this repo is rendered correctly not only on an iPhone but also on a Mac. Its metadata and gain map are accurately interpreted by Adobe's demo app and third-party image viewers like HoneyViewer. 

The insightful discussions and the generous sharing of reference implementations were indispensable to this project. Much of the code and ideas were derived from these discussions, and I would like to extend my sincere gratitude to all the contributors and participants in the online discussions for their invaluable input.

## Usage and Code Structure

The code is straightforward, with the main functionality located in `main.swift`. There are two primary functions.

* `ExtractGainMap()`, is responsible for extracting metadata associated with the gain map from a photo taken by an iPhone. It can also save the extracted gain map as a PNG file. Using the gain map and an SDR photo, one can calculate the pixel values for the HDR photo following Apple's documentation, for which detailed documents and reference implementations are available online.
* `writeAuxiliaryDataToImage()`, performs the inverse of the `ExtractGainMap` function. It takes an SDR image and a gain map image to produce a special formatted JPEG image that can be displayed on iPhones, Macs, and compatible third-party software.

To utilize this script, four pieces of information are required.

1. A reference image from an iPhone, which can be either a raw DNG or an HEIC image, containing the necessary HDR metadata. 
2. Sn SDR image, which should be a JPEG (PNG might not work) in RGB format and 8-bit, which will be the base image for rendering on SDR devices. 
3. A gain map file, which influences the appearance of the HDR image and should be a grayscale 8-bit image.
4. The path to the generated output image.

Once these pieces of information are gathered and specified in the code, one can use Swift and the command `swift main.swift` to run the script and produce an HDR image. The generated HDR image can be viewed as HDR in the Photos app on both iPhone and Mac. However, when viewed in the Files app on iPhone or the Finder and Preview apps on Mac, it renders as SDR. The script can only run on a Mac. Even though Windows can also run Swift scripts, the script relies on some Mac-Native Frameworks to do the heavylifting.

The repo provides some sample image to begin with. Directly running the script would generate `HDR.jpg`, which appears pure white in SDR, but shows a text HDR when viewing in HDR mode.

## Limitations

This work has several limitations. 
1. The code quality is not up to par as this was my first time using Swift in about seven or eight years. The project was more about exploratory prototyping, which led to subpar code. For instance, I often used the force unwrapping operator to save development time, but this means that when unwrapping fails, the error messages are not very helpful. I would greatly appreciate any assistance in improving the code quality.
2. The approach taken did not involve constructing the relevant metadata structures from the ground up; instead, it relied on reusing a reference image from an iPhone. This choice sped up development but potentially sacrificed flexibility and control over the metadata. I would welcome help from someone with expertise in the relevant APIs to construct these data structures from scratch.
3. The current version of the generated HDR image does not display an HDR indicator in the top left corner of the screen. There are [some potential solutions](https://developer.apple.com/forums/thread/709331) online that I have not yet verified or implemented. 
4. The workflow for generating gain maps has not been addressed, and the specific meaning of the values in each pixel remains unclear/unverified. While this is beyond the scope of this project, any discussions on this topic would be very helpful.