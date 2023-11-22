
function azl --wraps='az login --use-device-code' --description 'alias azl=az login --use-device-code'
  az login --use-device-code $argv  
end



