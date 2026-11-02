import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

class DocumentPageText {
  const DocumentPageText({required this.page,required this.text});
  final int page;
  final String text;
}
class DocumentExtraction {
  const DocumentExtraction({required this.pages,required this.text});
  final List<DocumentPageText> pages;
  final String text;
}

/// On-device OCR. Images and rendered PDF pages are processed locally only.
class DocumentTextExtractor {
  Future<String> extractImage(Uint8List bytes,String extension) async {
    final result=await _recognize(bytes,extension);
    return result.text;
  }

  Future<DocumentExtraction> extractPdf(Uint8List bytes,{int maxPages=20}) async {
    if(bytes.isEmpty)throw const FormatException('The selected PDF is empty.');
    final document=await PdfDocument.openData(bytes);
    final pages=<DocumentPageText>[];
    try{
      final count=document.pagesCount;
      if(count>maxPages)throw FormatException('This PDF has $count pages. For on-device OCR, select a PDF with $maxPages pages or fewer.');
      for(var number=1;number<=count;number++){
        final page=await document.getPage(number);
        try{
          final rendered=await page.render(width:(page.width*1.5).clamp(900,1800).toDouble(),height:(page.height*1.5).clamp(1200,2400).toDouble(),format:PdfPageImageFormat.jpeg,quality:85);
          if(rendered==null)continue;
          final result=await _recognize(rendered.bytes,'jpg');
          pages.add(DocumentPageText(page:number,text:result.text));
        }finally{await page.close();}
      }
    }finally{await document.close();}
    return DocumentExtraction(pages:List.unmodifiable(pages),text:pages.map((e)=>'[Page ${e.page}]\n${e.text}').where((e)=>e.trim().isNotEmpty).join('\\n\\n'));
  }

  Future<DocumentExtraction> extractImagePages(Uint8List bytes,String extension)async{
    final result=await _recognize(bytes,extension);
    return DocumentExtraction(pages:[DocumentPageText(page:1,text:result.text)],text:result.text);
  }

  Future<DocumentPageText> _recognize(Uint8List bytes,String extension)async{
    if(!{'jpg','jpeg','png','webp'}.contains(extension.toLowerCase()))throw const FormatException('Supported image formats are JPG, PNG and WebP.');
    if(bytes.isEmpty)throw const FormatException('The selected image is empty.');
    final cache=await getTemporaryDirectory();
    final temp=File(p.join(cache.path,'ujexa_ocr_${DateTime.now().microsecondsSinceEpoch}.$extension'));
    try{
      await temp.writeAsBytes(bytes,flush:true);
      final recognizer=TextRecognizer(script:TextRecognitionScript.latin);
      try{
        final result=await recognizer.processImage(InputImage.fromFilePath(temp.path));
        return DocumentPageText(page:1,text:result.text.trim());
      }finally{await recognizer.close();}
    }finally{if(await temp.exists())await temp.delete();}
  }
}
