# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0006 V6)
class_name StageResult
extends RefCounted

var outcome: Flow.Phase = Flow.Phase.BUILD
var lives_left: int = 0
