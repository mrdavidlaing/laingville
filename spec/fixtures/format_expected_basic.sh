#!/bin/bash

Describe 'Basic formatting test'
It 'should handle simple indentation'
echo "test"
End

Context 'when testing nested structures'
It 'should indent properly'
echo "nested"
End
End
End
