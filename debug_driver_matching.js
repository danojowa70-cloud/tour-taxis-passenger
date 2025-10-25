// Debug script to check why passengers can't find drivers
import { createClient } from '@supabase/supabase-js'

// Replace with your actual Supabase URL and key
const supabaseUrl = 'YOUR_SUPABASE_URL'
const supabaseKey = 'YOUR_SUPABASE_ANON_KEY'
const supabase = createClient(supabaseUrl, supabaseKey)

async function debugDriverMatching() {
  console.log('🔍 Debugging Driver Matching System...\n')

  try {
    // 1. Check if drivers table exists and has data
    console.log('1️⃣ Checking drivers table...')
    const { data: driversCount, error: countError } = await supabase
      .from('drivers')
      .select('*', { count: 'exact', head: true })
    
    if (countError) {
      console.error('❌ Error accessing drivers table:', countError.message)
      return
    }
    
    console.log(`✅ Found ${driversCount.length || 0} total drivers in database`)

    // 2. Check online drivers
    console.log('\n2️⃣ Checking online drivers...')
    const { data: onlineDrivers, error: onlineError } = await supabase
      .from('drivers')
      .select('id, name, is_online, is_available, current_latitude, current_longitude, last_location_update')
      .eq('is_online', true)
    
    if (onlineError) {
      console.error('❌ Error fetching online drivers:', onlineError.message)
    } else {
      console.log(`✅ Found ${onlineDrivers.length} online drivers`)
      onlineDrivers.forEach(driver => {
        console.log(`  - ${driver.name || driver.id}: online=${driver.is_online}, available=${driver.is_available}`)
        console.log(`    Location: ${driver.current_latitude}, ${driver.current_longitude}`)
        console.log(`    Last seen: ${driver.last_location_update}`)
      })
    }

    // 3. Check available drivers with location
    console.log('\n3️⃣ Checking available drivers with location...')
    const { data: availableDrivers, error: availableError } = await supabase
      .from('drivers')
      .select('*')
      .eq('is_online', true)
      .eq('is_available', true)
      .not('current_latitude', 'is', null)
      .not('current_longitude', 'is', null)
    
    if (availableError) {
      console.error('❌ Error fetching available drivers:', availableError.message)
    } else {
      console.log(`✅ Found ${availableDrivers.length} available drivers with location data`)
    }

    // 4. Test get_nearby_drivers function
    console.log('\n4️⃣ Testing get_nearby_drivers function...')
    // Using sample coordinates (San Francisco) - replace with your test coordinates
    const testLat = 37.7749
    const testLng = -122.4194
    const testRadius = 50 // 50km radius for testing
    
    const { data: nearbyDrivers, error: functionError } = await supabase
      .rpc('get_nearby_drivers', {
        lat: testLat,
        lng: testLng,
        radius_km: testRadius
      })
    
    if (functionError) {
      console.error('❌ Error calling get_nearby_drivers:', functionError.message)
      console.log('💡 This likely means the function doesn\'t exist or has the wrong signature')
    } else {
      console.log(`✅ get_nearby_drivers returned ${nearbyDrivers.length} drivers`)
      nearbyDrivers.forEach(driver => {
        console.log(`  - ${driver.name}: ${driver.distance_km?.toFixed(2)}km away`)
      })
    }

    // 5. Check recent driver activity
    console.log('\n5️⃣ Checking recent driver activity...')
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000).toISOString()
    const { data: recentDrivers, error: recentError } = await supabase
      .from('drivers')
      .select('id, name, last_location_update')
      .gte('last_location_update', thirtyMinutesAgo)
    
    if (recentError) {
      console.error('❌ Error checking recent activity:', recentError.message)
    } else {
      console.log(`✅ Found ${recentDrivers.length} drivers active in last 30 minutes`)
    }

    // 6. Summary and recommendations
    console.log('\n📋 SUMMARY & RECOMMENDATIONS:')
    
    if (driversCount.length === 0) {
      console.log('❌ No drivers in database - you need to add drivers first')
    } else if (onlineDrivers.length === 0) {
      console.log('❌ No online drivers - drivers need to go online using update_driver_online_status')
    } else if (availableDrivers.length === 0) {
      console.log('❌ No drivers have location data - drivers need to call update_driver_location')
    } else if (functionError) {
      console.log('❌ get_nearby_drivers function error - deploy the fixed SQL function')
    } else if (nearbyDrivers.length === 0) {
      console.log('❌ No drivers in test area - try different coordinates or larger radius')
    } else {
      console.log('✅ System looks healthy! Check your passenger app coordinates')
    }

  } catch (error) {
    console.error('❌ Unexpected error:', error)
  }
}

// Run the debug function
debugDriverMatching()