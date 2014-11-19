--[[
  This file is part of ESAI-CEU-UCH/kaggle-epilepsy (https://github.com/ESAI-CEU-UCH/kaggle-epilepsy)
  
  Copyright (c) 2014, ESAI, Universidad CEU Cardenal Herrera,
  (F. Zamora-Martínez, F. Muñoz-Malmaraz, P. Botella-Rocamora, J. Pardo)
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
]]

package.path = package.path .. ";./scripts/?.lua"
--
local common = require "common"
local DATA_PATH = common.DATA_PATH
local SEQUENCES_PATH = common.SEQUENCES_PATH
local OUTPUT_PATH = common.TMP_PATH .. "/FFT_60s_30s_BFPLOS"

os.execute("mkdir -p %s"%{OUTPUT_PATH})

local NUM_CORES = util.omp_get_num_threads()
local WSIZE     = 60   -- seconds
local WADVANCE  = 30   -- seconds

-- sequences output file handler
local seqf = io.open(SEQUENCES_PATH, "a")
for _,conf in ipairs({
    { HZ=400, MASK="/Dog_*/*.mat", }, -- Dogs
    { HZ=5000, MASK="/Patient_*/*.mat", }, -- Patients
}) do
  local HZ = conf.HZ
  -- the FFT_SIZE is the closest power of two
  local FFT_SIZE = 2^(math.floor(math.log(HZ*WSIZE) / math.log(2)))
  -- compute the filter function following PLOS ONE paper + logarithm
  local filter   = common.compute_PLOS_filter(HZ, FFT_SIZE)
  local list = glob(DATA_PATH .. conf.MASK)
  -- process all subjects applying filter function
  local sequences = parallel_foreach(NUM_CORES, list,
                                     common.make_prep_function(HZ, FFT_SIZE,
                                                               WSIZE, WADVANCE,
                                                               OUTPUT_PATH,
                                                               filter),
                                     tostring)
  -- write sequences into output sequences file
  for i,v in ipairs(sequences) do
    if v ~= -1 then -- -1 indicates a filename which hasn't be processed
      fprintf(seqf, "%s %d\n", list[i]:basename():gsub(".mat$",""), v)
      seqf:flush()
    end
  end
end
seqf:close()