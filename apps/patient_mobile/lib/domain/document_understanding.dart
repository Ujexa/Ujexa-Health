class DocumentCandidate {
  const DocumentCandidate({required this.kind,required this.value,required this.evidence,required this.page,required this.confidence});
  final String kind,value,evidence;
  final int page;
  final double confidence;
}
class StructuredDocumentCandidate {
  const StructuredDocumentCandidate({
    required this.kind,required this.fields,required this.evidence,
    required this.page,required this.heuristicConfidence,
  });
  final String kind;
  final Map<String,String> fields;
  final String evidence;
  final int page;
  final double heuristicConfidence;
}

class DocumentUnderstanding {
  const DocumentUnderstanding({required this.suggestedType,required this.typeConfidence,required this.candidates,required this.structuredCandidates,required this.notes});
  final String suggestedType;
  final double typeConfidence;
  final List<DocumentCandidate> candidates;
  final List<StructuredDocumentCandidate> structuredCandidates;
  final List<String> notes;
}
class DocumentUnderstandingEngine {
  static DocumentUnderstanding analyze(String text){
    final lower=text.toLowerCase();
    final scores=<String,int>{
      'lab_report':_count(lower,['laboratory','specimen','reference range','result','haemoglobin','hemoglobin','glucose','creatinine']),
      'prescription':_count(lower,['prescription','dosage','take one','tablet','capsule','refills','frequency']),
      'discharge_summary':_count(lower,['discharge summary','admission','discharge date','hospital course']),
      'imaging_report':_count(lower,['radiology','impression','findings','ultrasound','x-ray','mri','ct scan']),
      'referral':_count(lower,['referral','referred to','consultation requested']),
      'vaccination_record':_count(lower,['vaccination','vaccine','immunization','immunisation']),
      'insurance':_count(lower,['policy number','insurance','premium','beneficiary']),
    };
    var best='other';var score=0;
    for(final entry in scores.entries){if(entry.value>score){best=entry.key;score=entry.value;}}
    final candidates=<DocumentCandidate>[];
    final structured=<StructuredDocumentCandidate>[];
    final lines=text.split(RegExp(r'[\r\n]+'));
    final number=RegExp(r'(?<![A-Za-z])([0-9]+(?:[.,][0-9]+)?)\s*(mg/dL|mmol/L|g/dL|mmHg|bpm|kg|cm|°C|%)',caseSensitive:false);
    for(var i=0;i<lines.length;i++){
      final line=lines[i].trim();
      if(line.isEmpty)continue;
      for(final match in number.allMatches(line)){
        final prefix=line.substring(0,match.start).trim();
        if(prefix.length<2)continue;
        final value='${match.group(1)} ${match.group(2)}';
        final label=prefix.replaceAll(RegExp(r'[:=\-]+$'),'').trim();
        candidates.add(DocumentCandidate(kind:'measurement_candidate',value:value,evidence:line,page:_pageAt(text,text.indexOf(line)),confidence:0.55));
        final reference=RegExp(r'(?:reference(?: range)?|normal range)\s*[:=]?\s*([0-9]+(?:[.,][0-9]+)?\s*(?:-|to)\s*[0-9]+(?:[.,][0-9]+)?\s*[^,;]*)',caseSensitive:false).firstMatch(line);
        structured.add(StructuredDocumentCandidate(kind:'lab_result_candidate',fields:{
          'test_name':label,'value':value,
          if(reference!=null)'reference_range':reference.group(1)!.trim(),
        },evidence:line,page:_pageAt(text,text.indexOf(line)),heuristicConfidence:0.55));
        if(candidates.length>=40)break;
      }
      if(candidates.length>=40)break;
    }
    final datePattern=RegExp(r'\b(?:date|collected|reported|issued)\s*[:\-]?\s*([0-3]?\d[/-][01]?\d[/-](?:19|20)?\d{2}|(?:19|20)\d{2}-[01]\d-[0-3]\d)',caseSensitive:false);
    for(final match in datePattern.allMatches(text)){
      structured.add(StructuredDocumentCandidate(kind:'document_date_candidate',fields:{'date_text':match.group(1)!},evidence:match.group(0)!,page:_pageAt(text,match.start),heuristicConfidence:0.45));
    }
    final medication=RegExp(r'\b(?:take|use)\s+(?:one|two|[0-9]+)\s+(?:tablet|tablets|capsule|capsules|ml)\b',caseSensitive:false);
    for(final match in medication.allMatches(text)){
      final instruction=match.group(0)!;
      candidates.add(DocumentCandidate(kind:'instruction_candidate',value:instruction,evidence:instruction,page:_pageAt(text,match.start),confidence:0.5));
      structured.add(StructuredDocumentCandidate(kind:'medication_instruction_candidate',fields:{'instruction_text':instruction},evidence:instruction,page:_pageAt(text,match.start),heuristicConfidence:0.5));
      if(candidates.length>=60)break;
    }
    return DocumentUnderstanding(suggestedType:best,typeConfidence:score==0?0.0:(score/(score+3)).clamp(0.0,0.9),candidates:List.unmodifiable(candidates),structuredCandidates:List.unmodifiable(structured),notes:const[
      'Document type is a keyword-based suggestion, not a verified classification.',
      'Extracted values and instructions are candidates only. OCR may omit, merge or misread characters.',
      'Candidate confidence is a heuristic review priority, not a calibrated probability or clinical confidence score.',
      'No candidate is automatically written into a structured health record.',
    ]);
  }
  static int _count(String text,List<String> terms)=>terms.where(text.contains).length;
  static int _pageAt(String text,int offset){
    final prefix=text.substring(0,offset.clamp(0,text.length));
    return RegExp(r'\[Page ([0-9]+)\]').allMatches(prefix).fold<int>(1,(v,m)=>int.tryParse(m.group(1)!)??v);
  }
}
